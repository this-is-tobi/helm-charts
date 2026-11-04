#!/bin/bash
set -euo pipefail

# Checks of the vso-utils chart: lint, then the mount and path of static secrets, which an entry
# sets itself or takes from vaultStaticSecretDefaults (both rendered through tpl), and the errors
# for a secret that ends up without either. Only those two fields of a render are read. Then the
# spec of VaultAuth objects: method and mount from the entry or vaultAuthDefaults, and login
# rendered under the method they resolve to.

CHART_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../charts/vso-utils" && pwd)"

if [ ! -d "${CHART_DIR}/charts" ]; then
  helm repo add hashicorp https://helm.releases.hashicorp.com >/dev/null 2>&1 || true
  helm dependency build "${CHART_DIR}" >/dev/null
fi

echo "==> helm lint"
helm lint "${CHART_DIR}" --values "${CHART_DIR}/test-values.yaml"

SECRET='{"vaultAuthRef":"default","destination":{"name":"s"}}'
work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT
# Templates go through values files: --set reads braces as a list.
cat >"${work}/templated.yaml" <<'YAML'
global: {x: kv, prefix: platforms/x}
vaultStaticSecretDefaults:
  mount: '{{ .Values.global.x }}'
  path: '{{ .Values.global.prefix }}/app'
YAML
cat >"${work}/empty-path.yaml" <<'YAML'
vaultStaticSecretDefaults:
  mount: kv
  path: '{{ with dig "none" "" (.Values.global | default dict) }}{{ . }}/app{{ end }}'
YAML

# mount_path <helm args...>: "<mount> <path>" of every VaultStaticSecret, one per line, sorted.
mount_path() {
  helm template release-name "${CHART_DIR}" "$@" \
    | yq -r 'select(.kind == "VaultStaticSecret") | .spec.mount + " " + .spec.path' \
    | grep -v '^---$' | sort
}

expect() {
  local label="$1" want="$2"
  shift 2
  echo "==> ${label}"
  local got
  got="$(mount_path "$@")"
  if [ "${got}" != "${want}" ]; then
    echo "ERROR: expected '${want}', got '${got}'" >&2
    exit 1
  fi
}

expect_failure() {
  local label="$1" message="$2"
  shift 2
  echo "==> expect failure: ${label}"
  local err
  if err="$(helm template release-name "${CHART_DIR}" "$@" 2>&1 >/dev/null)"; then
    echo "ERROR: expected '${label}' to fail, but it rendered" >&2
    exit 1
  fi
  if ! grep -qF -- "${message}" <<<"${err}"; then
    echo "ERROR: expected '${message}', got: ${err}" >&2
    exit 1
  fi
}

expect "an entry's own mount and path" "kv a/b" \
  --set-json "vaultStaticSecrets={\"app\":$(jq -c '. + {mount: "kv", path: "a/b"}' <<<"${SECRET}")}"
expect "an entry's own mount and path win over the defaults" "kv a/b" \
  --set-json "vaultStaticSecrets={\"app\":$(jq -c '. + {mount: "kv", path: "a/b"}' <<<"${SECRET}")}" \
  --set vaultStaticSecretDefaults.mount=other --set vaultStaticSecretDefaults.path=other/path
expect "an entry without mount and path takes the defaults" "kv2 p/q" \
  --set-json "vaultStaticSecrets={\"app\":${SECRET}}" \
  --set vaultStaticSecretDefaults.mount=kv2 --set vaultStaticSecretDefaults.path=p/q
expect "the defaults render through tpl with the chart's root context" "kv platforms/x/app" \
  --set-json "vaultStaticSecrets={\"app\":${SECRET}}" --values "${work}/templated.yaml"

# Every entry of test-values.yaml renders the mount and path it sets, else the defaults.
want="$(yq -r '.vaultStaticSecretDefaults as $d | .vaultStaticSecrets[] | (.mount // $d.mount) + " " + (.path // $d.path)' "${CHART_DIR}/test-values.yaml" | sort)"
expect "test-values.yaml renders each entry's mount and path, else the defaults" "${want}" \
  --values "${CHART_DIR}/test-values.yaml"

expect_failure "a path template that renders empty" "path is required for VaultStaticSecret app" \
  --set-json "vaultStaticSecrets={\"app\":${SECRET}}" --values "${work}/empty-path.yaml"
expect_failure "no mount on the entry nor in the defaults" "mount is required for VaultStaticSecret app" \
  --set-json "vaultStaticSecrets={\"app\":${SECRET}}" --set vaultStaticSecretDefaults.path=p

cat >"${work}/login.yaml" <<'YAML'
global: {m: jwt, p: jwt-dev}
vaultAuthDefaults:
  method: '{{ .Values.global.m }}'
  mount: '{{ .Values.global.p }}'
vaultAuth:
  default:
    login: {role: gitea, serviceAccount: vso, audiences: [vault]}
YAML

# auth_spec <helm args...>: the spec of every VaultAuth, as JSON with sorted keys, one per line.
auth_spec() {
  helm template release-name "${CHART_DIR}" "$@" \
    | yq -o=json -I=0 'select(.kind == "VaultAuth") | .spec' \
    | jq -cS .
}

expect_auth() {
  local label="$1" want
  want="$(jq -cS . <<<"$2")"
  shift 2
  echo "==> ${label}"
  local got
  got="$(auth_spec "$@")"
  if [ "${got}" != "${want}" ]; then
    echo "ERROR: expected '${want}', got '${got}'" >&2
    exit 1
  fi
}

LOGIN='"role":"gitea","serviceAccount":"vso","audiences":["vault"]'
expect_auth "login under the method the defaults resolve to" \
  "{\"method\":\"jwt\",\"mount\":\"jwt-dev\",\"jwt\":{${LOGIN}}}" \
  --values "${work}/login.yaml"
expect_auth "login under kubernetes when the defaults resolve to it" \
  "{\"method\":\"kubernetes\",\"mount\":\"kubernetes\",\"kubernetes\":{${LOGIN}}}" \
  --values "${work}/login.yaml" --set global.m=kubernetes --set global.p=kubernetes
expect_auth "the method's own block is merged over login" \
  '{"method":"kubernetes","mount":"kubernetes","kubernetes":{"role":"override","serviceAccount":"vso","audiences":["vault"]}}' \
  --values "${work}/login.yaml" --set global.m=kubernetes --set global.p=kubernetes --set vaultAuth.default.kubernetes.role=override
expect_auth "with login, another method's block is left out" \
  "{\"method\":\"jwt\",\"mount\":\"jwt-dev\",\"jwt\":{${LOGIN}}}" \
  --values "${work}/login.yaml" --set vaultAuth.default.kubernetes.role=override
expect_auth "an entry with its own method, mount and block renders as before" \
  '{"method":"kubernetes","mount":"kubernetes","kubernetes":{"role":"x"}}' \
  --set-json 'vaultAuth={"default":{"method":"kubernetes","mount":"kubernetes","kubernetes":{"role":"x"}}}'

expect_failure "no method on the VaultAuth entry nor in the defaults" "method is required for VaultAuth default" \
  --set-json 'vaultAuth={"default":{"mount":"kubernetes","login":{"role":"x"}}}'
expect_failure "no mount on the VaultAuth entry nor in the defaults" "mount is required for VaultAuth default" \
  --set-json 'vaultAuth={"default":{"method":"kubernetes","login":{"role":"x"}}}'
expect_failure "login with a method other than kubernetes or jwt" "login needs the kubernetes or jwt method" \
  --set-json 'vaultAuth={"default":{"method":"appRole","mount":"approle","login":{"role":"x"}}}'

echo "==> all vso-utils checks passed"
