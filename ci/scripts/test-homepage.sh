#!/bin/bash
set -euo pipefail

# Static checks of the homepage chart (lint, render + schema validation, rendered security, OpenShift
# wiring, allowed hosts, authentication, cluster access and values that must be refused). With
# `--e2e`, also exercises the chart against the current kube context (the kind cluster in CI):
# restricted Pod Security admission, host validation, an OpenShift-like arbitrary UID, service
# discovery through the chart's RBAC, and the authentication gate.

KUBECONFORM_VERSION="0.7.0"
KUBERNETES_VERSION="1.31.0"
CHART_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../charts/homepage" && pwd)"
OPENSHIFT=(--api-versions security.openshift.io/v1 --api-versions route.openshift.io/v1)

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
  helm template release-name "${CHART_DIR}" --namespace homepage "$@" \
    | kubeconform \
        -strict \
        -summary \
        -ignore-missing-schemas \
        -kubernetes-version "${KUBERNETES_VERSION}" \
        -schema-location default \
        -schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' \
        -
}

AUTH=(--set auth.enabled=true --set auth.externalUrl=https://home.example.com)
# shellcheck disable=SC2016
OIDC=("${AUTH[@]}" --set auth.oidc.enabled=true --set auth.oidc.issuer=https://auth.example.com/realms/home
  --set auth.oidc.clientId=homepage --set auth.secret.existingSecret=homepage-oidc)
DISCOVERY=(--set kubernetes.enabled=true --set-json 'config.kubernetes={"ingress":true,"traefik":true,"gateway":true}')

render "chart defaults"
render "ingress" --set ingress.enabled=true --set ingress.className=nginx
render "httpRoute" --set httpRoute.enabled=true --set 'httpRoute.parentRefs[0].name=gateway' --set 'httpRoute.hostnames[0]=home.example.com'
render "autoscaling + pdb" --set autoscaling.enabled=true --set pdb.enabled=true
render "digest-pinned image" --set "image.digest=sha256:$(printf '0%.0s' {1..64})"
render "kubernetes integration" --set kubernetes.enabled=true
render "kubernetes discovery (ingress, traefik, gateway)" "${DISCOVERY[@]}"
render "authentication with a password" "${AUTH[@]}"
render "authentication with an existing secret" "${AUTH[@]}" --set auth.secret.existingSecret=homepage-auth
render "authentication with OIDC" "${OIDC[@]}" --set auth.oidc.name=Keycloak --set 'auth.oidc.scope=openid email' --set auth.oidc.autoLogin=true
render "network policy" --set networkPolicy.enabled=true --set kubernetes.enabled=true \
  --set-json 'networkPolicy.ingress.from=[{"namespaceSelector":{"matchLabels":{"kubernetes.io/metadata.name":"ingress-nginx"}}}]' \
  --set-json 'networkPolicy.egress.rules=[{"to":[{"ipBlock":{"cidr":"192.168.0.0/16"}}],"ports":[{"protocol":"TCP","port":8096}]}]'
render "config" --set-json 'config.settings={"title":"Home"}' --set-json 'config.services=[{"Media":[{"Plex":{"href":"https://plex.example.com"}}]}]' \
  --set-json 'config.bookmarks=[{"Dev":[{"GitHub":[{"abbr":"GH","href":"https://github.com"}]}]}]' --set customCss='body { color: red; }'
render "OpenShift" "${OPENSHIFT[@]}" "${DISCOVERY[@]}" "${AUTH[@]}"
render "everything" "${OPENSHIFT[@]}" "${DISCOVERY[@]}" "${AUTH[@]}" --set ingress.enabled=true --set autoscaling.enabled=true --set pdb.enabled=true --set networkPolicy.enabled=true

# Parent charts toggle this one with `condition: homepage.enabled`, which hands it that key.
echo "==> render as a dependency of a parent chart"
PARENT_DIR="$(mktemp -d)"
cat >"${PARENT_DIR}/Chart.yaml" <<EOF
apiVersion: v2
name: parent
version: 0.0.0
dependencies:
  - name: homepage
    version: ">=0.0.0-0"
    repository: file://${CHART_DIR}
    condition: homepage.enabled
EOF
helm dependency build "${PARENT_DIR}" >/dev/null
helm template parent "${PARENT_DIR}" --set homepage.enabled=true >/dev/null
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

DEPLOYMENT=(--show-only templates/deployment.yaml)
CONFIGMAP=(--show-only templates/configmap.yaml)

echo "==> Homepage pod: read-only root filesystem, no ServiceAccount token, no service links"
expect_count 1 'readOnlyRootFilesystem: true'
expect_count 1 'automountServiceAccountToken: false' "${DEPLOYMENT[@]}"
expect_count 1 'automountServiceAccountToken: false' --show-only templates/serviceaccount.yaml
expect_count 1 'enableServiceLinks: false'
expect_count 0 'kind: ClusterRole'
# Homepage copies a skeleton over a missing file and exits when it cannot: the ConfigMap holds all of them.
files="$(helm template release-name "${CHART_DIR}" "${CONFIGMAP[@]}" | yq e -N '.data | keys | sort | join(" ")' -)" || exit 1
if [ "${files}" != "bookmarks.yaml custom.css custom.js docker.yaml kubernetes.yaml proxmox.yaml services.yaml settings.yaml widgets.yaml" ]; then
  echo "ERROR: the ConfigMap holds '${files}', Homepage needs all nine config files" >&2
  exit 1
fi

echo "==> config files follow the values"
expect_count 1 'title: Home' "${CONFIGMAP[@]}" --set-json 'config.settings={"title":"Home"}'
expect_count 1 'color: red' "${CONFIGMAP[@]}" --set customCss='body { color: red; }'
# Placeholders are Homepage's, not Helm's: they must reach the file as written.
# shellcheck disable=SC2016
expect_count 1 '{{HOMEPAGE_VAR_PLEX_KEY}}' "${CONFIGMAP[@]}" --set-json 'config.widgets=[{"plex":{"key":"{{HOMEPAGE_VAR_PLEX_KEY}}"}}]'

echo "==> cluster access: none by default, only what discovery needs when enabled"
expect_count 1 'mode: disabled' "${CONFIGMAP[@]}"
expect_count 1 'mode: cluster' "${CONFIGMAP[@]}" --set kubernetes.enabled=true
expect_count 1 'mode: default' "${CONFIGMAP[@]}" --set kubernetes.enabled=true --set config.kubernetes.mode=default
expect_count 1 'automountServiceAccountToken: true' "${DEPLOYMENT[@]}" --set kubernetes.enabled=true
expect_count 1 'automountServiceAccountToken: true' --show-only templates/serviceaccount.yaml --set kubernetes.enabled=true
expect_count 1 '^kind: ClusterRole$' --set kubernetes.enabled=true
expect_count 1 '^kind: ClusterRoleBinding$' --set kubernetes.enabled=true
expect_count 0 '^kind: ClusterRole' --set kubernetes.enabled=true --set kubernetes.rbac.create=false
expect_count 1 'ingresses' --set kubernetes.enabled=true
expect_count 0 'ingressroutes' --set kubernetes.enabled=true
expect_count 0 'httproutes' --set kubernetes.enabled=true
expect_count 1 'ingressroutes' --set kubernetes.enabled=true --set config.kubernetes.traefik=true
expect_count 1 'customresourcedefinitions/status' --set kubernetes.enabled=true --set config.kubernetes.traefik=true
expect_count 1 'httproutes' --set kubernetes.enabled=true --set config.kubernetes.gateway=true
expect_count 1 'apisixroutes' --set kubernetes.enabled=true --set-json 'kubernetes.rbac.extraRules=[{"apiGroups":["apisix.apache.org"],"resources":["apisixroutes"],"verbs":["get","list"]}]'
# The binding must target the ServiceAccount the pod runs as.
subject="$(helm template release-name "${CHART_DIR}" --namespace homepage --set kubernetes.enabled=true --set serviceAccount.name=custom \
  --show-only templates/rbac.yaml | yq e -N 'select(.kind == "ClusterRoleBinding") | .subjects[0].name + "/" + .subjects[0].namespace' -)" || exit 1
if [ "${subject}" != "custom/homepage" ]; then
  echo "ERROR: the ClusterRoleBinding targets '${subject}' instead of custom/homepage" >&2
  exit 1
fi

# The value of HOMEPAGE_ALLOWED_HOSTS, empty when the variable is not set; it must be set once at most.
allowed_hosts() {
  local env
  env="$(helm template release-name "${CHART_DIR}" "${DEPLOYMENT[@]}" "$@" | yq e -N '.spec.template.spec.containers[0].env' -)" || exit 1
  if [ "$(grep -c 'name: HOMEPAGE_ALLOWED_HOSTS' <<<"${env}" || true)" -gt 1 ]; then
    echo "ERROR: HOMEPAGE_ALLOWED_HOSTS is set more than once with '$*'" >&2
    exit 1
  fi
  yq e -N '.[] | select(.name == "HOMEPAGE_ALLOWED_HOSTS") | .value' - <<<"${env}"
}

expect_allowed_hosts() {
  local want="$1" got
  shift
  got="$(allowed_hosts "$@")" || exit 1
  if [ "${got}" != "${want}" ]; then
    echo "ERROR: expected HOMEPAGE_ALLOWED_HOSTS '${want}' with '$*', got '${got}'" >&2
    exit 1
  fi
}

echo "==> allowed hosts: derived from the routes the chart creates, overridable"
expect_allowed_hosts ""
expect_allowed_hosts "" --set ingress.enabled=false
expect_allowed_hosts "homepage.local" --set ingress.enabled=true
expect_allowed_hosts "home.example.com" --set httpRoute.enabled=true --set 'httpRoute.parentRefs[0].name=gateway' --set 'httpRoute.hostnames[0]=home.example.com'
expect_allowed_hosts "home.example.com" --set httpRoute.enabled=true --set 'httpRoute.parentRefs[0].name=gateway' \
  --set-json 'httpRoute.hostnames=["*.example.com","home.example.com"]'
expect_allowed_hosts "home.example.com:8443" --set auth.enabled=true --set auth.externalUrl=https://home.example.com:8443
expect_allowed_hosts "apisix.example.com,other.example.com:8443" --set-json 'allowedHosts=["apisix.example.com","other.example.com:8443"]'
expect_allowed_hosts "homepage.local,home.example.com,extra.example.com" --set ingress.enabled=true --set httpRoute.enabled=true \
  --set 'httpRoute.parentRefs[0].name=gateway' --set 'httpRoute.hostnames[0]=home.example.com' --set-json 'allowedHosts=["extra.example.com","home.example.com"]'
expect_allowed_hosts "*" --set ingress.enabled=true --set-json 'allowedHosts=["*","extra.example.com"]'
expect_allowed_hosts "mine.example.com" --set ingress.enabled=true --set-json 'env=[{"name":"HOMEPAGE_ALLOWED_HOSTS","value":"mine.example.com"}]'

echo "==> logs go to stdout unless env says otherwise"
expect_count 1 'name: LOG_TARGETS' "${DEPLOYMENT[@]}"
expect_count 1 'value: stdout' "${DEPLOYMENT[@]}"
expect_count 1 'name: LOG_TARGETS' "${DEPLOYMENT[@]}" --set-json 'env=[{"name":"LOG_TARGETS","value":"both"}]'
expect_count 0 'value: stdout' "${DEPLOYMENT[@]}" --set-json 'env=[{"name":"LOG_TARGETS","value":"both"}]'

echo "==> authentication: off by default, a generated or existing Secret, password or OIDC"
expect_count 0 'HOMEPAGE_AUTH' "${DEPLOYMENT[@]}"
expect_count 0 '^kind: Secret$'
expect_count 0 'HOMEPAGE_EXTERNAL_URL' "${DEPLOYMENT[@]}"
expect_count 1 'name: HOMEPAGE_AUTH_ENABLED' "${DEPLOYMENT[@]}" "${AUTH[@]}"
expect_count 1 'name: HOMEPAGE_AUTH_SECRET' "${DEPLOYMENT[@]}" "${AUTH[@]}"
expect_count 1 'name: HOMEPAGE_AUTH_PASSWORD' "${DEPLOYMENT[@]}" "${AUTH[@]}"
expect_count 1 'value: "https://home.example.com"' "${DEPLOYMENT[@]}" "${AUTH[@]}"
expect_count 1 '^kind: Secret$' "${AUTH[@]}"
expect_count 2 'name: release-name-homepage-auth$' "${DEPLOYMENT[@]}" "${AUTH[@]}"
expect_count 0 '^kind: Secret$' "${AUTH[@]}" --set auth.secret.existingSecret=homepage-auth
expect_count 2 'name: homepage-auth$' "${DEPLOYMENT[@]}" "${AUTH[@]}" --set auth.secret.existingSecret=homepage-auth
expect_count 1 'key: pw$' "${DEPLOYMENT[@]}" "${AUTH[@]}" --set auth.secret.existingSecret=homepage-auth --set auth.secret.passwordKey=pw
expect_count 1 'name: HOMEPAGE_OIDC_ISSUER' "${DEPLOYMENT[@]}" "${OIDC[@]}"
expect_count 1 'name: HOMEPAGE_OIDC_CLIENT_ID' "${DEPLOYMENT[@]}" "${OIDC[@]}"
expect_count 1 'name: HOMEPAGE_OIDC_CLIENT_SECRET' "${DEPLOYMENT[@]}" "${OIDC[@]}"
expect_count 0 'HOMEPAGE_AUTH_PASSWORD' "${DEPLOYMENT[@]}" "${OIDC[@]}"
expect_count 0 'HOMEPAGE_OIDC_AUTO_LOGIN' "${DEPLOYMENT[@]}" "${OIDC[@]}"
expect_count 1 'HOMEPAGE_OIDC_AUTO_LOGIN' "${DEPLOYMENT[@]}" "${OIDC[@]}" --set auth.oidc.autoLogin=true
expect_count 1 'HOMEPAGE_OIDC_NAME' "${DEPLOYMENT[@]}" "${OIDC[@]}" --set auth.oidc.name=Keycloak
expect_count 0 '^kind: Secret$' "${OIDC[@]}"

echo "==> network policy: off by default; DNS and the Homepage port only, plus what the values add"
NETPOL=(--show-only templates/networkpolicy.yaml --set networkPolicy.enabled=true)
expect_count 0 'kind: NetworkPolicy'
expect_count 1 'kind: NetworkPolicy' "${NETPOL[@]}"
expect_count 1 'port: 3000' "${NETPOL[@]}"
expect_count 0 'from:' "${NETPOL[@]}"
expect_count 1 'ingress-nginx' "${NETPOL[@]}" --set-json 'networkPolicy.ingress.from=[{"namespaceSelector":{"matchLabels":{"kubernetes.io/metadata.name":"ingress-nginx"}}}]'
expect_count 0 'port: 6443' "${NETPOL[@]}"
expect_count 1 'port: 6443' "${NETPOL[@]}" --set kubernetes.enabled=true
expect_count 1 '192.168.0.0/16' "${NETPOL[@]}" --set-json 'networkPolicy.egress.rules=[{"to":[{"ipBlock":{"cidr":"192.168.0.0/16"}}]}]'
expect_egress_rules() {
  local want="$1" got
  shift
  got="$(helm template release-name "${CHART_DIR}" "${NETPOL[@]}" "$@" | yq e -N '.spec.egress | length' -)" || exit 1
  if [ "${got}" != "${want}" ]; then
    echo "ERROR: expected ${want} egress rules with '$*', got ${got}" >&2
    exit 1
  fi
}
expect_egress_rules 1
expect_egress_rules 2 --set kubernetes.enabled=true
expect_egress_rules 2 --set-json 'networkPolicy.egress.rules=[{"to":[{"ipBlock":{"cidr":"10.0.0.0/8"}}]}]'
expect_egress_rules 3 --set kubernetes.enabled=true --set-json 'networkPolicy.egress.rules=[{"to":[{"ipBlock":{"cidr":"10.0.0.0/8"}}]}]'
# An empty rule allows every destination: the documented way to restrict only the ingress.
expect_count 1 '^  - {}$' "${NETPOL[@]}" --set-json 'networkPolicy.egress.rules=[{}]'

echo "==> Deployment: bounded history, annotations for what reads them there"
expect_count 1 'revisionHistoryLimit: 3' "${DEPLOYMENT[@]}"
expect_count 1 'revisionHistoryLimit: 0' "${DEPLOYMENT[@]}" --set revisionHistoryLimit=0
expect_count 0 'reloader.stakater.com/auto' "${DEPLOYMENT[@]}"
annotation="$(helm template release-name "${CHART_DIR}" "${DEPLOYMENT[@]}" --set-json 'deploymentAnnotations={"reloader.stakater.com/auto":"true"}' \
  | yq e -N '.metadata.annotations["reloader.stakater.com/auto"]' -)" || exit 1
if [ "${annotation}" != "true" ]; then
  echo "ERROR: the Deployment does not carry its annotations (got '${annotation}')" >&2
  exit 1
fi

echo "==> overrides documented in the README: merge key by key, null removes"
expect_count 1 'startupProbe:' "${DEPLOYMENT[@]}"
expect_count 1 'startupProbe:' "${DEPLOYMENT[@]}" --set-json 'startupProbe={}'
expect_count 0 'startupProbe:' "${DEPLOYMENT[@]}" --set startupProbe=null
expect_count 0 'readinessProbe:' "${DEPLOYMENT[@]}" --set readinessProbe=null
expect_count 0 'livenessProbe:' "${DEPLOYMENT[@]}" --set livenessProbe=null
expect_count 1 'readOnlyRootFilesystem: false' "${DEPLOYMENT[@]}" --set securityContext.readOnlyRootFilesystem=false
expect_count 1 'allowPrivilegeEscalation: false' "${DEPLOYMENT[@]}" --set securityContext.readOnlyRootFilesystem=false
expect_count 0 'capabilities:' "${DEPLOYMENT[@]}" --set securityContext.capabilities=null
expect_count 0 'kind: ServiceAccount' --set serviceAccount.create=false
expect_count 0 'kind: ClusterRole' --set kubernetes.enabled=true --set kubernetes.rbac.create=false --set serviceAccount.create=false

echo "==> security contexts follow global.compatibility.openshift.adaptSecurityContext"
expect_count 1 'runAsUser:'
expect_count 0 'runAsUser:' "${OPENSHIFT[@]}"
expect_count 0 'runAsUser:' --set global.compatibility.openshift.adaptSecurityContext=force
expect_count 1 'runAsUser:' "${OPENSHIFT[@]}" --set global.compatibility.openshift.adaptSecurityContext=disabled
expect_count 0 'fsGroup:' "${OPENSHIFT[@]}"
expect_count 1 'runAsNonRoot: true' "${OPENSHIFT[@]}"

# Every container the chart can run has requests and limits, runs non-root with seccomp, no
# privilege escalation and no capabilities, and pins its image (no `latest`): what quotas and
# policy engines commonly require.
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
      or .securityContext.readOnlyRootFilesystem != true
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
expect_hardened "OpenShift" "${OPENSHIFT[@]}"
expect_hardened "digest-pinned image" --set "image.digest=sha256:$(printf '0%.0s' {1..64})"
expect_hardened "everything" "${OPENSHIFT[@]}" "${DISCOVERY[@]}" "${AUTH[@]}" --set ingress.enabled=true

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

expect_failure "malformed image digest" "must be a full digest" --set image.digest=notadigest
expect_failure "latest image tag" "tag" --set image.tag=latest
expect_failure "unknown value (typo)" "servcie" --set servcie.port=80
expect_failure "unknown config file" "nginx" --set-json 'config.nginx={}'
expect_failure "services as a map" "services" --set-json 'config.services={"Media":[]}'
expect_failure "unknown Kubernetes mode" "mode" --set config.kubernetes.mode=sometimes
expect_failure "auth secret key not usable as a data key" "authSecretKey" --set auth.secret.authSecretKey=a/b
expect_failure "unknown OpenShift mode" "adaptSecurityContext" --set global.compatibility.openshift.adaptSecurityContext=sometimes
expect_failure "ingress without hosts" "requires at least one host" --set ingress.enabled=true --set ingress.hosts=null
expect_failure "ingress host without paths" "paths" --set ingress.enabled=true --set-json 'ingress.hosts=[{"name":"home.example.com"}]'
expect_failure "httpRoute without parentRefs" "requires httpRoute.parentRefs" --set httpRoute.enabled=true
expect_failure "pdb without budget" "requires pdb.maxUnavailable or pdb.minAvailable" --set pdb.enabled=true --set pdb.maxUnavailable=
expect_failure "pdb with both budgets" "are exclusive" --set pdb.enabled=true --set pdb.minAvailable=1
expect_failure "autoscaling minReplicas above maxReplicas" "cannot exceed" --set autoscaling.enabled=true --set autoscaling.minReplicas=4
expect_failure "autoscaling without target" "requires a CPU or memory" --set autoscaling.enabled=true --set autoscaling.targetCPUUtilizationPercentage=
expect_failure "autoscaling target not a number" "targetCPUUtilizationPercentage" --set autoscaling.targetCPUUtilizationPercentage=eighty
expect_failure "network policy peers as a map" "from" --set-json 'networkPolicy.ingress.from={"podSelector":{}}'
expect_failure "network policy egress rules as a map" "rules" --set-json 'networkPolicy.egress.rules={"to":[]}'
expect_failure "network policy unknown key (typo)" "egres" --set-json 'networkPolicy.egres={}'
expect_failure "negative revision history" "revisionHistoryLimit" --set revisionHistoryLimit=-1
expect_failure "allowed host with a scheme" "Host header" --set-json 'allowedHosts=["https://home.example.com"]'
expect_failure "allowed host with a path" "Host header" --set-json 'allowedHosts=["home.example.com/dash"]'
expect_failure "authentication without external URL" "requires auth.externalUrl" --set auth.enabled=true
expect_failure "authentication with a bare host as external URL" "requires auth.externalUrl" --set auth.enabled=true --set auth.externalUrl=home.example.com
expect_failure "external URL with credentials" "requires auth.externalUrl" --set auth.enabled=true --set auth.externalUrl=https://user:pass@home.example.com
expect_failure "OIDC without authentication" "requires auth.enabled" --set auth.oidc.enabled=true
expect_failure "OIDC without issuer" "auth.oidc.issuer" "${AUTH[@]}" --set auth.oidc.enabled=true --set auth.oidc.clientId=homepage \
  --set auth.secret.existingSecret=homepage-oidc
expect_failure "OIDC without client ID" "auth.oidc.clientId" "${AUTH[@]}" --set auth.oidc.enabled=true --set auth.oidc.issuer=https://auth.example.com \
  --set auth.secret.existingSecret=homepage-oidc
expect_failure "OIDC without existing secret" "requires auth.secret.existingSecret" "${AUTH[@]}" --set auth.oidc.enabled=true \
  --set auth.oidc.issuer=https://auth.example.com --set auth.oidc.clientId=homepage
expect_failure "cluster mode without the integration" "requires kubernetes.enabled" --set config.kubernetes.mode=cluster
expect_failure "integration with mode disabled" "contradicts" --set kubernetes.enabled=true --set config.kubernetes.mode=disabled
expect_failure "discovery options without the integration" "has no effect" --set config.kubernetes.traefik=true

echo "==> all static checks passed"

[ "${1:-}" = "--e2e" ] || exit 0

NS="homepage-e2e"
RELEASE="homepage"
HOST="home.e2e.example.com"
PEER_NS="${NS}-peer"

cleanup() {
  helm uninstall "${RELEASE}" --namespace "${NS}" --wait >/dev/null 2>&1 || true
  kubectl delete namespace "${NS}" --wait=false >/dev/null 2>&1 || true
  kubectl delete namespace "${PEER_NS}" --wait=false >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Request Homepage from inside the pod, as a given Host: prints the body, fails on a 4xx or 5xx.
get() {
  local host="$1" path="$2"
  kubectl -n "${NS}" exec "deploy/${RELEASE}" -c homepage -- wget -q -O - --header "Host: ${host}" "http://127.0.0.1:3000${path}"
}

# /api/healthcheck goes through the host validation, / renders a page from the full configuration.
check_http() {
  local host="${1:-localhost:3000}" path
  for path in /api/healthcheck /; do
    get "${host}" "${path}" >/dev/null
  done
}

auth_hash() {
  kubectl -n "${NS}" get secret "${RELEASE}-auth" -o jsonpath='{.data}' | sha256sum
}

echo "==> e2e: admitted under Pod Security 'restricted', serving"
kubectl create namespace "${NS}"
kubectl label namespace "${NS}" pod-security.kubernetes.io/enforce=restricted
helm install "${RELEASE}" "${CHART_DIR}" --namespace "${NS}" --wait --timeout 4m
check_http
if get "unknown.example.com" /api/healthcheck >/dev/null 2>&1; then
  echo "ERROR: Homepage answered a Host it was not told about" >&2
  exit 1
fi

echo "==> e2e: the host of the ingress is allowed, others are not"
helm upgrade "${RELEASE}" "${CHART_DIR}" --namespace "${NS}" --wait --timeout 4m \
  --set ingress.enabled=true --set 'ingress.hosts[0].name='"${HOST}" --set 'ingress.hosts[0].paths[0].path=/' \
  --set-json 'allowedHosts=["apisix.e2e.example.com"]'
check_http "${HOST}"
check_http "apisix.e2e.example.com"
check_http
if get "unknown.example.com" /api/healthcheck >/dev/null 2>&1; then
  echo "ERROR: Homepage answered a Host it was not told about" >&2
  exit 1
fi

echo "==> e2e: OpenShift-like arbitrary UID and GID 0, as an SCC assigns them"
helm upgrade "${RELEASE}" "${CHART_DIR}" --namespace "${NS}" --wait --timeout 4m \
  --set podSecurityContext.runAsUser=1000650000 --set podSecurityContext.runAsGroup=null \
  --set podSecurityContext.fsGroup=1000650000
check_http

echo "==> e2e: service discovery through the chart's RBAC, from an annotated Ingress"
kubectl apply -n "${NS}" -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: discovered
  annotations:
    gethomepage.dev/enabled: "true"
    gethomepage.dev/name: Discovered E2E
    gethomepage.dev/group: E2E
    gethomepage.dev/description: found by the chart's ClusterRole
spec:
  rules:
  - host: discovered.e2e.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: discovered
            port:
              number: 80
EOF
# Off: no token, so no discovery.
if grep -q "Discovered E2E" <<<"$(get localhost:3000 /api/services || true)"; then
  echo "ERROR: Homepage discovered a service without kubernetes.enabled" >&2
  exit 1
fi
helm upgrade "${RELEASE}" "${CHART_DIR}" --namespace "${NS}" --wait --timeout 4m \
  --set kubernetes.enabled=true --set config.kubernetes.ingress=true
discovered=""
for _ in $(seq 1 15); do
  if grep -q "Discovered E2E" <<<"$(get localhost:3000 /api/services || true)"; then
    discovered=yes
    break
  fi
  sleep 2
done
if [ -z "${discovered}" ]; then
  echo "ERROR: Homepage did not discover the annotated Ingress" >&2
  kubectl -n "${NS}" logs "deploy/${RELEASE}" -c homepage --tail=30 >&2 || true
  exit 1
fi

echo "==> e2e: network policy, enforced as written (skipped when the cluster does not enforce them)"
# Policies take a moment to reach the CNI: retry until a connection is, or is not, possible.
eventually() {
  local _
  for _ in $(seq 1 20); do
    if "$@" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  return 1
}
eventually_not() {
  local _
  for _ in $(seq 1 20); do
    if ! "$@" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  return 1
}
discovered_service() {
  grep -q "Discovered E2E" <<<"$(get localhost:3000 /api/services || true)"
}
homepage_reaches_peer() {
  kubectl -n "${NS}" exec "deploy/${RELEASE}" -c homepage -- wget -q -T 3 -O /dev/null "http://np-target.${PEER_NS}.svc"
}
peer_reaches_homepage() {
  kubectl -n "${PEER_NS}" exec np-client -- wget -q -T 3 -O /dev/null --header "Host: localhost:3000" "http://${RELEASE}.${NS}.svc:3000/api/healthcheck"
}
peer_reaches_target() {
  kubectl -n "${PEER_NS}" exec np-client -- wget -q -T 3 -O /dev/null http://np-target
}
kubectl create namespace "${PEER_NS}"
kubectl -n "${PEER_NS}" run np-target --image=busybox:1.37 --restart=Never -- sh -c 'mkdir -p /www && echo ok >/www/index.html && httpd -f -p 80 -h /www'
kubectl -n "${PEER_NS}" expose pod np-target --port 80
kubectl -n "${PEER_NS}" run np-client --image=busybox:1.37 --restart=Never --labels=app=np-client -- sleep 3600
kubectl -n "${PEER_NS}" wait --for=condition=Ready pod/np-target pod/np-client --timeout=120s
# Canary: a policy the cluster ignores would make every check below meaningless.
kubectl -n "${PEER_NS}" apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: np-canary
spec:
  podSelector:
    matchLabels:
      app: np-client
  policyTypes: [Egress]
  egress:
  - ports:
    - protocol: UDP
      port: 53
EOF
if ! eventually_not peer_reaches_target; then
  echo "SKIP: this cluster does not enforce NetworkPolicy, the rendered policy was checked above"
else
  kubectl -n "${PEER_NS}" delete networkpolicy np-canary
  eventually peer_reaches_target

  helm upgrade "${RELEASE}" "${CHART_DIR}" --namespace "${NS}" --wait --timeout 4m \
    --set kubernetes.enabled=true --set config.kubernetes.ingress=true --set networkPolicy.enabled=true
  check_http
  # DNS is allowed, the connection is not.
  kubectl -n "${NS}" exec "deploy/${RELEASE}" -c homepage -- nslookup "np-target.${PEER_NS}.svc.cluster.local" >/dev/null
  if ! eventually_not homepage_reaches_peer; then
    echo "ERROR: Homepage reached a destination no egress rule allows" >&2
    exit 1
  fi
  # The API server rule: discovery keeps working with the policy on.
  if ! eventually discovered_service; then
    echo "ERROR: Homepage lost the Kubernetes API behind the network policy" >&2
    exit 1
  fi
  # No `from`: any source reaches the port.
  if ! eventually peer_reaches_homepage; then
    echo "ERROR: Homepage is not reachable on its port with networkPolicy.ingress.from empty" >&2
    exit 1
  fi

  allow_peer="[{\"to\":[{\"namespaceSelector\":{\"matchLabels\":{\"kubernetes.io/metadata.name\":\"${PEER_NS}\"}}}],\"ports\":[{\"protocol\":\"TCP\",\"port\":80}]}]"
  only_own_namespace="[{\"namespaceSelector\":{\"matchLabels\":{\"kubernetes.io/metadata.name\":\"${NS}\"}}}]"
  helm upgrade "${RELEASE}" "${CHART_DIR}" --namespace "${NS}" --wait --timeout 4m \
    --set networkPolicy.enabled=true --set-json "networkPolicy.egress.rules=${allow_peer}" \
    --set-json "networkPolicy.ingress.from=${only_own_namespace}"
  check_http
  if ! eventually homepage_reaches_peer; then
    echo "ERROR: networkPolicy.egress.rules did not open the destination it lists" >&2
    exit 1
  fi
  if ! eventually_not peer_reaches_homepage; then
    echo "ERROR: networkPolicy.ingress.from did not close Homepage to the other namespaces" >&2
    exit 1
  fi
fi

echo "==> e2e: authentication gate, with a generated secret kept across upgrades"
helm upgrade "${RELEASE}" "${CHART_DIR}" --namespace "${NS}" --wait --timeout 4m \
  --set kubernetes.enabled=true --set config.kubernetes.ingress=true \
  --set auth.enabled=true --set auth.externalUrl=http://localhost:3000
hash_before="$(auth_hash)"
# The health check stays public; everything else sends visitors to the sign-in page.
check_http_health="$(get localhost:3000 /api/healthcheck)"
if [ "${check_http_health}" != "up" ]; then
  echo "ERROR: /api/healthcheck answered '${check_http_health}' instead of 'up' with authentication on" >&2
  exit 1
fi
if grep -q "Discovered E2E" <<<"$(get localhost:3000 /api/services || true)"; then
  echo "ERROR: /api/services answered without a session" >&2
  exit 1
fi
helm upgrade "${RELEASE}" "${CHART_DIR}" --namespace "${NS}" --wait --timeout 4m \
  --set kubernetes.enabled=true --set config.kubernetes.ingress=true \
  --set auth.enabled=true --set auth.externalUrl=http://localhost:3000 --set replicaCount=2
if [ "$(auth_hash)" != "${hash_before}" ]; then
  echo "ERROR: the generated auth secret changed across helm upgrade" >&2
  exit 1
fi

echo "==> all e2e checks passed"
