#!/bin/bash
set -euo pipefail

# Lints the scaffold chart in `template/` and renders it for every workload kind it supports,
# validating the output against the Kubernetes API schemas. The chart is excluded from
# chart-testing (no maintainers, never released), so without this it would ship unchecked.

KUBECONFORM_VERSION="0.7.0"
KUBERNETES_VERSION="1.31.0"
CHART_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../template" && pwd)"

# install kubeconform
if ! command -v kubeconform >/dev/null 2>&1; then
  curl --silent --show-error --fail --location --output /tmp/kubeconform.tar.gz \
    "https://github.com/yannh/kubeconform/releases/download/v${KUBECONFORM_VERSION}/kubeconform-linux-amd64.tar.gz"
  tar -xf /tmp/kubeconform.tar.gz -C /tmp kubeconform
  export PATH="/tmp:${PATH}"
fi

echo "==> helm lint"
helm lint "${CHART_DIR}"

# One entry per supported `deploymentType`: the base fixture covers Deployment, the other two
# layer a per-kind overlay on top of it so the shared configuration is maintained once.
render() {
  local label="$1"
  shift
  echo "==> render + validate: ${label}"
  helm template release-name "${CHART_DIR}" "$@" \
    | kubeconform \
        -strict \
        -summary \
        -ignore-missing-schemas \
        -kubernetes-version "${KUBERNETES_VERSION}" \
        -
}

render "chart defaults"
render "digest-pinned image" --set "servicename.image.digest=sha256:$(printf '0%.0s' {1..64})"
render "NodePort service" --set servicename.service.type=NodePort
# maxUnavailable=0 is falsy but meaningful (blocks every voluntary eviction) - guards the
# truthiness bug where it would silently fall through to minAvailable.
render "pdb with maxUnavailable 0" \
  --set servicename.pdb.enabled=true --set servicename.pdb.maxUnavailable=0
render "Deployment" -f "${CHART_DIR}/test-values.yaml"
render "StatefulSet" -f "${CHART_DIR}/test-values.yaml" -f "${CHART_DIR}/test-values-statefulset.yaml"
render "DaemonSet" -f "${CHART_DIR}/test-values.yaml" -f "${CHART_DIR}/test-values-daemonset.yaml"

# The chart is expected to REFUSE these, rather than silently rendering a release with no workload
# or a manifest the API server rejects.
expect_failure() {
  local label="$1"
  shift
  echo "==> expect failure: ${label}"
  if helm template release-name "${CHART_DIR}" "$@" >/dev/null 2>&1; then
    echo "ERROR: expected '${label}' to fail values validation, but it rendered successfully" >&2
    exit 1
  fi
}

expect_failure "unknown deploymentType" --set servicename.deploymentType=NotAKind
expect_failure "autoscaling on a DaemonSet" \
  --set servicename.deploymentType=DaemonSet --set servicename.autoscaling.enabled=true
expect_failure "volumeClaims on a Deployment" \
  --set servicename.deploymentType=Deployment --set 'servicename.volumeClaims[0].metadata.name=data'
expect_failure "invalid service type" --set servicename.service.type=NotAServiceType
expect_failure "pdb with no budget" --set servicename.pdb.enabled=true
expect_failure "malformed image digest" --set servicename.image.digest=notadigest
expect_failure "chart-level ingress without a backend service" \
  --set global.ingress.enabled=true \
  --set 'global.ingress.hosts[0].name=a.local' \
  --set 'global.ingress.hosts[0].paths[0].path=/'
expect_failure "autoscaling with no metric" \
  --set servicename.autoscaling.enabled=true \
  --set servicename.autoscaling.targetCPUUtilizationPercentage=null \
  --set servicename.autoscaling.targetMemoryUtilizationPercentage=null

echo "==> all template chart checks passed"
