#!/bin/bash
set -euo pipefail

# Checks of the vso-utils chart: lint, then the mount and path of static secrets, which an entry
# sets itself or takes from vaultStaticSecretDefaults (both rendered through tpl), and the errors
# for a secret that ends up without either. Only those two fields of a render are read.

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

echo "==> all vso-utils checks passed"
