#!/bin/bash
set -euo pipefail

# Static checks of the searxng chart (lint, render + schema validation, rendered security, OpenShift
# and valkey wiring, values that must be refused). With `--e2e`, also exercises the chart against the
# current kube context (the kind cluster in CI): restricted Pod Security admission, the secret key
# across upgrades, an OpenShift-like arbitrary UID, and valkey with the startup wait.

KUBECONFORM_VERSION="0.7.0"
KUBERNETES_VERSION="1.31.0"
CHART_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../charts/searxng" && pwd)"
OPENSHIFT=(--api-versions security.openshift.io/v1 --api-versions route.openshift.io/v1)

# install kubeconform
if ! command -v kubeconform >/dev/null 2>&1; then
  curl --silent --show-error --fail --location --output /tmp/kubeconform.tar.gz \
    "https://github.com/yannh/kubeconform/releases/download/v${KUBECONFORM_VERSION}/kubeconform-linux-amd64.tar.gz"
  tar -xf /tmp/kubeconform.tar.gz -C /tmp kubeconform
  export PATH="/tmp:${PATH}"
fi

helm dependency build "${CHART_DIR}" >/dev/null

echo "==> helm lint"
helm lint "${CHART_DIR}"

render() {
  local label="$1"
  shift
  echo "==> render + validate: ${label}"
  helm template release-name "${CHART_DIR}" --namespace searxng "$@" \
    | kubeconform \
        -strict \
        -summary \
        -ignore-missing-schemas \
        -kubernetes-version "${KUBERNETES_VERSION}" \
        -schema-location default \
        -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
        -
}

render "chart defaults"
render "valkey" -f "${CHART_DIR}/ci/valkey-values.yaml"
render "ingress" --set ingress.enabled=true --set ingress.className=nginx
render "httpRoute" --set httpRoute.enabled=true --set 'httpRoute.parentRefs[0].name=gateway' --set 'httpRoute.hostnames[0]=search.example.com'
render "serviceMonitor" --set settings.general.open_metrics=password --set serviceMonitor.enabled=true \
  --set serviceMonitor.basicAuth.password.name=metrics --set serviceMonitor.basicAuth.password.key=password
render "autoscaling + pdb" --set autoscaling.enabled=true --set pdb.enabled=true
render "existing secret" --set secret.existingSecret=searxng-secret
render "digest-pinned image" --set "image.digest=sha256:$(printf '0%.0s' {1..64})"
render "OpenShift" "${OPENSHIFT[@]}" -f "${CHART_DIR}/ci/valkey-values.yaml"

# Parent charts toggle this one with `condition: searxng.enabled`, which hands it that key.
echo "==> render as a dependency of a parent chart"
PARENT_DIR="$(mktemp -d)"
cat >"${PARENT_DIR}/Chart.yaml" <<EOF
apiVersion: v2
name: parent
version: 0.0.0
dependencies:
  - name: searxng
    version: ">=0.0.0-0"
    repository: file://${CHART_DIR}
    condition: searxng.enabled
EOF
helm dependency build "${PARENT_DIR}" >/dev/null
helm template parent "${PARENT_DIR}" --set searxng.enabled=true --set searxng.valkey.enabled=true >/dev/null
rm -rf "${PARENT_DIR}"

# Render first, then count: a failed render must fail the script, not count as zero matches (bash
# clears `set -e` inside command substitutions, hence the explicit exits).
count() {
  local pattern="$1" manifest
  shift
  manifest="$(helm template release-name "${CHART_DIR}" "$@")" || exit 1
  grep -c -- "${pattern}" <<<"${manifest}" || true
}

expect_count() {
  local want="$1" pattern="$2" got
  shift 2
  got="$(count "${pattern}" "$@")"
  if [ "${got}" != "${want}" ]; then
    echo "ERROR: expected ${want} x '${pattern}' with '$*', got ${got}" >&2
    exit 1
  fi
}

echo "==> SearXNG pod: read-only root filesystem, no ServiceAccount token, no service links"
expect_count 1 'readOnlyRootFilesystem: true'
expect_count 1 'automountServiceAccountToken: false' --show-only templates/deployment.yaml
expect_count 1 'enableServiceLinks: false'

echo "==> settings.yml keeps SearXNG's defaults, or the map form given"
CONFIGMAP=(--show-only templates/configmap.yaml)
expect_count 1 'use_default_settings: true' "${CONFIGMAP[@]}"
expect_count 0 'use_default_settings: true' "${CONFIGMAP[@]}" --set-json 'settings.use_default_settings={"engines":{"keep_only":["duckduckgo"]}}'
expect_count 1 'keep_only:' "${CONFIGMAP[@]}" --set-json 'settings.use_default_settings={"engines":{"keep_only":["duckduckgo"]}}'

echo "==> security contexts follow global.compatibility.openshift.adaptSecurityContext"
expect_count 1 'runAsUser:'
expect_count 0 'runAsUser:' "${OPENSHIFT[@]}"
expect_count 0 'runAsUser:' --set global.compatibility.openshift.adaptSecurityContext=force
expect_count 1 'runAsUser:' "${OPENSHIFT[@]}" --set global.compatibility.openshift.adaptSecurityContext=disabled

echo "==> valkey subchart: seccomp profile, no volume, adapted to OpenShift"
VALKEY_STS=(--set valkey.enabled=true --show-only charts/valkey/templates/statefulset.yaml)
expect_count 1 'type: RuntimeDefault' "${VALKEY_STS[@]}"
expect_count 0 'volumeClaimTemplates:' "${VALKEY_STS[@]}"
expect_count 0 'runAsUser:\|fsGroup:' "${VALKEY_STS[@]}" "${OPENSHIFT[@]}"

# SearXNG must reach the valkey subchart's service with the password of the subchart's Secret,
# whatever the release and subchart names.
expect_valkey() {
  local release="$1" host="$2" port="$3" secret="$4" key="$5" deployment service
  shift 5
  deployment="$(helm template "${release}" "${CHART_DIR}" --set valkey.enabled=true "$@" --show-only templates/deployment.yaml)" || exit 1
  service="$(helm template "${release}" "${CHART_DIR}" --set valkey.enabled=true "$@" --show-only charts/valkey/templates/service.yaml)" || exit 1
  if ! grep -q "^  name: ${host}$" <<<"${service}"; then
    echo "ERROR: no valkey Service named ${host} (release ${release}, $*)" >&2
    exit 1
  fi
  if ! grep -q "until nc -w 2 ${host} ${port} " <<<"${deployment}"; then
    echo "ERROR: wait-for-valkey does not wait for ${host}:${port} (release ${release}, $*)" >&2
    exit 1
  fi
  if [ -n "${secret}" ]; then
    # shellcheck disable=SC2016 # the literal $(VALKEY_PASSWORD) that Kubernetes expands
    if ! grep -q 'value: "valkey://:$(VALKEY_PASSWORD)@'"${host}:${port}"'/0"' <<<"${deployment}" \
      || ! grep -A3 'name: VALKEY_PASSWORD' <<<"${deployment}" | grep -q "name: ${secret}$" \
      || ! grep -A4 'name: VALKEY_PASSWORD' <<<"${deployment}" | grep -q "key: ${key}$"; then
      echo "ERROR: SEARXNG_VALKEY_URL does not use ${secret}/${key} for ${host}:${port} (release ${release}, $*)" >&2
      exit 1
    fi
  elif ! grep -q "value: \"valkey://${host}:${port}/0\"" <<<"${deployment}" || grep -q 'VALKEY_PASSWORD' <<<"${deployment}"; then
    echo "ERROR: expected a password-less URL for ${host}:${port} (release ${release}, $*)" >&2
    exit 1
  fi
}

echo "==> valkey URL, password and wait target match the subchart"
expect_valkey searxng searxng-valkey 6379 searxng-valkey password
expect_valkey my-search my-search-valkey 6379 my-search-valkey password
expect_valkey my-search search-cache 6379 search-cache password --set valkey.fullnameOverride=search-cache
expect_valkey my-search my-search-valkey 6380 my-search-valkey password --set valkey.service.port=6380
expect_valkey my-search my-search-valkey 6379 valkey-auth secret-password \
  --set valkey.auth.existingSecret=valkey-auth --set valkey.auth.existingSecretPasswordKey=secret-password
expect_valkey my-search my-search-valkey 6379 "" "" --set valkey.auth.enabled=false
expect_count 0 'valkey'

# Every container the chart can run, the subchart's optional ones included, has requests and
# limits, runs non-root with seccomp, no privilege escalation and no capabilities, and pins its
# image (no `latest`): what quotas and policy engines commonly require.
# shellcheck disable=SC2016 # yq variables, not shell ones
HARDENED='
  select(.spec.template.spec.containers) | .spec.template.spec as $pod
  | (($pod.initContainers // []) + $pod.containers)[]
  | select(
      .resources.requests.cpu == null or .resources.requests.memory == null
      or .resources.limits.cpu == null or .resources.limits.memory == null
      or (.securityContext.runAsNonRoot // $pod.securityContext.runAsNonRoot) != true
      or (.securityContext.seccompProfile.type // $pod.securityContext.seccompProfile.type) != "RuntimeDefault"
      or .securityContext.allowPrivilegeEscalation != false
      or ((.securityContext.capabilities.drop // []) | contains(["ALL"])) == false
      or (.image | test(":latest(@|$)"))
      or (.image | test("@sha256:[0-9a-f]{64}$|:[^/:@]+$")) == false
    )
  | .name'

expect_hardened() {
  local label="$1" offenders
  shift
  echo "==> hardened containers: ${label}"
  offenders="$(helm template release-name "${CHART_DIR}" "$@" | yq e -N "${HARDENED}" -)" || exit 1
  if [ -n "${offenders}" ]; then
    echo "ERROR: not hardened (requests/limits, security context or pinned image): ${offenders//$'\n'/ }" >&2
    exit 1
  fi
}

expect_hardened "chart defaults"
expect_hardened "valkey" --set valkey.enabled=true
expect_hardened "valkey with its optional containers" --set valkey.enabled=true --set valkey.architecture=replication \
  --set valkey.sentinel.enabled=true --set valkey.sentinel.masterProxy.enabled=true --set valkey.metrics.enabled=true
expect_hardened "OpenShift" "${OPENSHIFT[@]}" --set valkey.enabled=true

# Each value must be refused for the reason given, not for any error.
expect_failure() {
  local label="$1" reason="$2" output
  shift 2
  echo "==> expect failure: ${label}"
  if output="$(helm template release-name "${CHART_DIR}" "$@" 2>&1)"; then
    echo "ERROR: expected '${label}' to fail values validation, but it rendered successfully" >&2
    exit 1
  fi
  if ! grep -qi -- "${reason}" <<<"${output}"; then
    echo "ERROR: '${label}' failed, but not on '${reason}':" >&2
    echo "${output}" >&2
    exit 1
  fi
}

expect_failure "settings without SearXNG's defaults" "use_default_settings must stay true" --set settings.use_default_settings=false
expect_failure "use_default_settings set to null" "use_default_settings" --set settings.use_default_settings=null
expect_failure "settings.yml in extraConfigFiles" "cannot hold settings.yml" --set-string 'extraConfigFiles.settings\.yml=x'
expect_failure "malformed image digest" "must be a full digest" --set image.digest=notadigest
expect_failure "latest image tag" "tag" --set image.tag=latest
expect_failure "unknown value (typo)" "servcie" --set servcie.port=80
expect_failure "secret key not usable as a data key" "key" --set secret.key=a/b
expect_failure "unknown OpenShift mode" "adaptSecurityContext" --set global.compatibility.openshift.adaptSecurityContext=sometimes
expect_failure "ingress without hosts" "requires at least one host" --set ingress.enabled=true --set ingress.hosts=null
expect_failure "ingress host without paths" "paths" --set ingress.enabled=true --set-json 'ingress.hosts=[{"name":"search.example.com"}]'
expect_failure "httpRoute without parentRefs" "requires httpRoute.parentRefs" --set httpRoute.enabled=true
expect_failure "serviceMonitor without open_metrics" "requires settings.general.open_metrics" --set serviceMonitor.enabled=true
expect_failure "serviceMonitor without basic auth" "requires serviceMonitor.basicAuth.password" \
  --set serviceMonitor.enabled=true --set settings.general.open_metrics=password
expect_failure "pdb without budget" "requires pdb.maxUnavailable or pdb.minAvailable" --set pdb.enabled=true --set pdb.maxUnavailable=
expect_failure "pdb with both budgets" "are exclusive" --set pdb.enabled=true --set pdb.minAvailable=1
expect_failure "autoscaling minReplicas above maxReplicas" "cannot exceed" --set autoscaling.enabled=true --set autoscaling.minReplicas=4
expect_failure "autoscaling without target" "requires a CPU or memory" --set autoscaling.enabled=true --set autoscaling.targetCPUUtilizationPercentage=
expect_failure "autoscaling target not a number" "targetCPUUtilizationPercentage" --set autoscaling.targetCPUUtilizationPercentage=eighty
expect_failure "valkey over TLS" "valkey.tls.enabled is not supported" \
  --set valkey.enabled=true --set valkey.tls.enabled=true --set valkey.tls.existingSecret=valkey-tls

echo "==> all static checks passed"

[ "${1:-}" = "--e2e" ] || exit 0

NS="searxng-e2e"
RELEASE="searxng"

cleanup() {
  helm uninstall "${RELEASE}" --namespace "${NS}" --wait >/dev/null 2>&1 || true
  kubectl delete namespace "${NS}" --wait=false >/dev/null 2>&1 || true
}
trap cleanup EXIT

# /healthz runs SearXNG's request setup; / renders a page from the full settings.
check_http() {
  local path
  for path in /healthz /; do
    kubectl -n "${NS}" exec "deploy/${RELEASE}" -c searxng -- wget -q -O /dev/null "http://127.0.0.1:8080${path}"
  done
}

secret_key_hash() {
  kubectl -n "${NS}" get secret "${RELEASE}" -o jsonpath='{.data.secret-key}' | sha256sum
}

echo "==> e2e: admitted under Pod Security 'restricted', serving"
kubectl create namespace "${NS}"
kubectl label namespace "${NS}" pod-security.kubernetes.io/enforce=restricted
helm install "${RELEASE}" "${CHART_DIR}" --namespace "${NS}" --wait --timeout 4m
check_http
key_hash="$(secret_key_hash)"

echo "==> e2e: OpenShift-like arbitrary UID and GID 0, as an SCC assigns them"
helm upgrade "${RELEASE}" "${CHART_DIR}" --namespace "${NS}" --wait --timeout 4m \
  --set podSecurityContext.runAsUser=1000650000 --set podSecurityContext.runAsGroup=null \
  --set podSecurityContext.fsGroup=1000650000
check_http

echo "==> e2e: valkey, SearXNG waiting for it at startup and connected with its password"
helm upgrade "${RELEASE}" "${CHART_DIR}" --namespace "${NS}" --wait --timeout 4m \
  -f "${CHART_DIR}/ci/valkey-values.yaml"
check_http
# SearXNG keeps a connection open; the exec adds one. The password is expanded in the pod, never here.
# shellcheck disable=SC2016
clients="$(kubectl -n "${NS}" exec "statefulset/${RELEASE}-valkey" -- \
  sh -c 'REDISCLI_AUTH="${VALKEY_PASSWORD}" valkey-cli info clients' | sed -n 's/^connected_clients:\([0-9]*\).*/\1/p')"
if [ "${clients:-0}" -lt 2 ]; then
  echo "ERROR: SearXNG is not connected to valkey (connected_clients=${clients:-none})" >&2
  kubectl -n "${NS}" logs "deploy/${RELEASE}" -c wait-for-valkey >&2 || true
  kubectl -n "${NS}" logs "deploy/${RELEASE}" -c searxng --tail=30 >&2 || true
  exit 1
fi

echo "==> e2e: secret key kept across upgrades"
if [ "$(secret_key_hash)" != "${key_hash}" ]; then
  echo "ERROR: the generated secret key changed across helm upgrade" >&2
  exit 1
fi

echo "==> all e2e checks passed"
