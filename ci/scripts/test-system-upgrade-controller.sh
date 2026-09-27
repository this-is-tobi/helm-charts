#!/bin/bash
set -euo pipefail

# Static checks of the system-upgrade-controller chart (lint, render + schema validation, values
# that must be refused, vendored CRD vs upstream). With `--e2e`, also exercises the chart against
# the current kube context (the kind cluster in CI): restricted Pod Security admission, Plan
# validation, and one full no-op upgrade Job lifecycle.

KUBECONFORM_VERSION="0.7.0"
KUBERNETES_VERSION="1.31.0"
CHART_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../charts/system-upgrade-controller" && pwd)"
APP_VERSION="$(sed -n 's/^appVersion: "\(.*\)"$/\1/p' "${CHART_DIR}/Chart.yaml")"

# install kubeconform
if ! command -v kubeconform >/dev/null 2>&1; then
  curl --silent --show-error --fail --location --output /tmp/kubeconform.tar.gz \
    "https://github.com/yannh/kubeconform/releases/download/v${KUBECONFORM_VERSION}/kubeconform-linux-amd64.tar.gz"
  tar -xf /tmp/kubeconform.tar.gz -C /tmp kubeconform
  export PATH="/tmp:${PATH}"
fi

echo "==> helm lint"
helm lint "${CHART_DIR}"

render() {
  local label="$1"
  shift
  echo "==> render + validate: ${label}"
  helm template release-name "${CHART_DIR}" --namespace system-upgrade --include-crds "$@" \
    | kubeconform \
        -strict \
        -summary \
        -ignore-missing-schemas \
        -kubernetes-version "${KUBERNETES_VERSION}" \
        -
}

render "chart defaults"
render "k3s preset (version)" -f "${CHART_DIR}/ci/k3s-preset-values.yaml"
render "k3s preset (channel)" --set k3s.enabled=true --set k3s.channel=https://update.k3s.io/v1-release/channels/stable
render "generic plans + planDefaults" \
  --set-json 'planDefaults={"labels":{"team":"ops"},"window":{"days":["sunday"],"startTime":"01:00","endTime":"05:00"}}' \
  --set-json 'plans={"os-patch":{"version":"v1","upgrade":{"image":"docker.io/library/alpine","command":["true"]}}}'
render "digest-pinned image" --set "image.digest=sha256:$(printf '0%.0s' {1..64})"
render "namespace created" --set namespace.create=true
render "no rbac" --set rbac.create=false

# The controller pod must stay free of hostPath volumes (Pod Security baseline) unless a Plan
# resolves a channel, the only case the host CA bundle is needed.
expect_host_ca() {
  local want="$1"
  shift
  local got
  got="$(helm template release-name "${CHART_DIR}" "$@" | grep -c 'hostPath:' || true)"
  if [ "${got}" != "${want}" ]; then
    echo "ERROR: expected ${want} hostPath volumes with '$*', got ${got}" >&2
    exit 1
  fi
}

echo "==> host CA mounts follow caCerts.hostPath"
expect_host_ca 0
expect_host_ca 0 -f "${CHART_DIR}/ci/k3s-preset-values.yaml"
expect_host_ca 3 --set k3s.enabled=true --set k3s.channel=https://update.k3s.io/v1-release/channels/stable
expect_host_ca 3 --set caCerts.hostPath=true
expect_host_ca 0 --set caCerts.hostPath=false --set k3s.enabled=true --set k3s.channel=https://example.com

expect_failure() {
  local label="$1"
  shift
  echo "==> expect failure: ${label}"
  if helm template release-name "${CHART_DIR}" "$@" >/dev/null 2>&1; then
    echo "ERROR: expected '${label}' to fail values validation, but it rendered successfully" >&2
    exit 1
  fi
}

expect_failure "k3s preset without version or channel" --set k3s.enabled=true
expect_failure "k3s preset with both version and channel" \
  --set k3s.enabled=true --set k3s.version=v1 --set k3s.channel=https://example.com
expect_failure "plan name defined twice" --set k3s.enabled=true --set k3s.version=v1 \
  --set-json 'plans={"server-plan":{"version":"v1","upgrade":{"image":"x"}}}'
expect_failure "plan without upgrade container" --set-json 'plans={"p":{"version":"v1"}}'
expect_failure "plan without version or channel" --set-json 'plans={"p":{"upgrade":{"image":"x"}}}'
expect_failure "malformed image digest" --set image.digest=notadigest
expect_failure "latest image tag" --set image.tag=latest
expect_failure "latest kubectl image" --set controller.job.kubectlImage=rancher/kubectl:latest
expect_failure "unknown caCerts.hostPath mode" --set caCerts.hostPath=sometimes
expect_failure "unknown value (typo)" --set rbac.craete=true
expect_failure "controllerName over 63 chars" --set "controllerName=$(printf 'a%.0s' {1..64})"

echo "==> vendored CRD matches upstream ${APP_VERSION}"
curl --silent --show-error --fail --location \
  "https://github.com/rancher/system-upgrade-controller/releases/download/${APP_VERSION}/crd.yaml" \
  | diff -u - "${CHART_DIR}/crds/plans.upgrade.cattle.io.yaml"

echo "==> all static checks passed"

[ "${1:-}" = "--e2e" ] || exit 0

NS="suc-e2e"
RELEASE="suc"
CONTROLLER="${RELEASE}-system-upgrade-controller"
NODE="$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')"

cleanup() {
  helm uninstall "${RELEASE}" --namespace "${NS}" --wait >/dev/null 2>&1 || true
  kubectl delete namespace "${NS}" --wait=false >/dev/null 2>&1 || true
  kubectl label node "${NODE}" system-upgrade-controller.test/target- >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "==> e2e: controller admitted under Pod Security 'restricted', Plans validated, no Job"
kubectl create namespace "${NS}"
kubectl label namespace "${NS}" pod-security.kubernetes.io/enforce=restricted
helm install "${RELEASE}" "${CHART_DIR}" --namespace "${NS}" \
  -f "${CHART_DIR}/ci/k3s-preset-values.yaml" --wait --timeout 3m
kubectl -n "${NS}" wait --for=condition=Validated --timeout=2m plan/server-plan plan/agent-plan
kubectl -n "${NS}" get lease "${CONTROLLER}" >/dev/null
if [ -n "$(kubectl -n "${NS}" get jobs -o name)" ]; then
  echo "ERROR: Plans targeting no node created upgrade Jobs" >&2
  exit 1
fi

echo "==> e2e: full upgrade Job lifecycle with a no-op Plan (cordon, run, uncordon)"
kubectl label namespace "${NS}" pod-security.kubernetes.io/enforce=privileged --overwrite
kubectl label node "${NODE}" system-upgrade-controller.test/target=e2e --overwrite
helm upgrade "${RELEASE}" "${CHART_DIR}" --namespace "${NS}" --reuse-values --wait --timeout 3m \
  --set-json 'plans={"noop":{"version":"1.37.0","cordon":true,"upgrade":{"image":"docker.io/library/busybox","command":["true"]},"nodeSelector":{"matchLabels":{"system-upgrade-controller.test/target":"e2e"}},"tolerations":[{"operator":"Exists"}]}}'
# The Plan's Complete condition is also true when it selected no node, so wait on what the
# controller writes once the Job succeeded: the plan hash label on the node. The Plan sets no
# concurrency on purpose, to exercise the chart's default of 1.
for _ in $(seq 60); do
  [ -n "$(kubectl get node "${NODE}" -o jsonpath='{.metadata.labels.plan\.upgrade\.cattle\.io/noop}')" ] && break
  sleep 5
done
if [ -z "$(kubectl get node "${NODE}" -o jsonpath='{.metadata.labels.plan\.upgrade\.cattle\.io/noop}')" ]; then
  echo "ERROR: node ${NODE} was never marked upgraded by plan/noop" >&2
  kubectl -n "${NS}" get plan/noop -o yaml >&2
  kubectl -n "${NS}" get jobs,pods -o wide >&2
  kubectl -n "${NS}" get events --sort-by=.lastTimestamp >&2
  kubectl -n "${NS}" logs "deploy/${CONTROLLER}" --tail=50 >&2
  exit 1
fi
if [ "$(kubectl get node "${NODE}" -o jsonpath='{.spec.unschedulable}')" = "true" ]; then
  echo "ERROR: node ${NODE} is still cordoned after the Plan completed" >&2
  exit 1
fi
# Upgrade Jobs inherit the Plan's labels and annotations, GitOps tracking ones included, so Argo CD
# would attribute them to the app; only their owner reference (GitOps tools never prune owned
# resources) keeps them from being pruned mid-upgrade. Fail if a controller release drops it.
owner="$(kubectl -n "${NS}" get jobs -l upgrade.cattle.io/plan=noop \
  -o jsonpath='{.items[0].metadata.ownerReferences[?(@.controller==true)].kind}/{.items[0].metadata.ownerReferences[?(@.controller==true)].name}')"
if [ "${owner}" != "Plan/noop" ]; then
  echo "ERROR: the upgrade Job is not owned by plan/noop (got '${owner}')" >&2
  exit 1
fi
# Reference shape of a real upgrade Job, for writing narrowly scoped policy exceptions.
kubectl -n "${NS}" get jobs -o yaml

echo "==> all e2e checks passed"
