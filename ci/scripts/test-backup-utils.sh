#!/bin/bash
set -euo pipefail

# Checks of the backup-utils chart: lint, then the per-backup service account and extra volumes.
# What a backup sets reaches its own CronJob only, an unset or empty key renders nothing, and the
# schema refuses a value of the wrong type. The e2e job's `--e2e` runs the same checks: they need
# no cluster.

CHART_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../charts/backup-utils" && pwd)"

echo "==> helm lint"
helm lint "${CHART_DIR}" --values "${CHART_DIR}/test-values.yaml"
helm lint "${CHART_DIR}" --values "${CHART_DIR}/test-multi-backups.yaml"

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT
cat >"${work}/two-backups.yaml" <<'YAML'
backups:
  vaultSnapshot:
    enabled: true
    type: vault
    job: {schedule: "0 22 * * *"}
    serviceAccountName: vault-backup
    automountServiceAccountToken: false
    extraVolumes:
    - name: vault-ca
      secret: {secretName: vault-tls}
    extraVolumeMounts:
    - name: vault-ca
      mountPath: /etc/vault-ca
      readOnly: true
  postgres:
    enabled: true
    type: postgres
    job: {schedule: "0 20 * * *"}
YAML

# pod <backup> <helm args...>: the pod spec of the backup's CronJob, as JSON with sorted keys.
pod() {
  local backup="$1"
  shift
  helm template release-name "${CHART_DIR}" "$@" \
    | yq -o=json -I=0 "select(.kind == \"CronJob\" and (.metadata.name | test(\"-${backup}\$\"))) | .spec.jobTemplate.spec.template.spec" \
    | jq -cS .
}

# expect <label> <jq filter> <want> <backup> <helm args...>: the filter over the backup's pod spec.
expect() {
  local label="$1" filter="$2" want="$3" backup="$4"
  shift 4
  echo "==> ${label}"
  local got
  got="$(pod "${backup}" "$@" | jq -cS "${filter}")"
  if [ "${got}" != "$(jq -cS . <<<"${want}")" ]; then
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

FOUR='{sa: .serviceAccountName, token: .automountServiceAccountToken, volumes: .volumes, mounts: .containers[0].volumeMounts}'

expect "a backup's service account, token mount, volumes and mounts reach its pod" "${FOUR}" \
  '{"sa":"vault-backup","token":false,"volumes":[{"name":"vault-ca","secret":{"secretName":"vault-tls"}}],"mounts":[{"name":"vault-ca","mountPath":"/etc/vault-ca","readOnly":true}]}' \
  vault-snapshot --values "${work}/two-backups.yaml"
expect "another backup of the release gets none of them" "${FOUR}" \
  '{"sa":null,"token":null,"volumes":null,"mounts":null}' \
  postgres --values "${work}/two-backups.yaml"
expect "automountServiceAccountToken true renders true" ".automountServiceAccountToken" "true" \
  vault-snapshot --values "${work}/two-backups.yaml" --set backups.vaultSnapshot.automountServiceAccountToken=true

echo "==> an empty service account and empty lists render as unset"
# Helm 4 keeps `--set key=null` as a null, which the schema refuses: unset keys come from a file without them.
yq 'del(.backups.vaultSnapshot.serviceAccountName, .backups.vaultSnapshot.automountServiceAccountToken, .backups.vaultSnapshot.extraVolumes, .backups.vaultSnapshot.extraVolumeMounts)' \
  "${work}/two-backups.yaml" >"${work}/unset.yaml"
unset_keys="$(pod vault-snapshot --values "${work}/unset.yaml")"
empty_keys="$(pod vault-snapshot --values "${work}/unset.yaml" --set backups.vaultSnapshot.serviceAccountName= \
  --set-json 'backups.vaultSnapshot.extraVolumes=[]' --set-json 'backups.vaultSnapshot.extraVolumeMounts=[]')"
if [ "${empty_keys}" != "${unset_keys}" ] || [ "$(jq -c "${FOUR}" <<<"${unset_keys}")" != '{"sa":null,"token":null,"volumes":null,"mounts":null}' ]; then
  echo "ERROR: empty keys render '${empty_keys}', unset keys '${unset_keys}'" >&2
  exit 1
fi

expect_failure "automountServiceAccountToken that is not a boolean" "automountServiceAccountToken" \
  --values "${work}/two-backups.yaml" --set-string backups.vaultSnapshot.automountServiceAccountToken=no
expect_failure "serviceAccountName that is not a string" "serviceAccountName" \
  --values "${work}/two-backups.yaml" --set-json backups.vaultSnapshot.serviceAccountName=1
expect_failure "extraVolumes that is not a list" "extraVolumes" \
  --values "${work}/two-backups.yaml" --set-json 'backups.vaultSnapshot.extraVolumes={"name":"x"}'
expect_failure "extraVolumeMounts that is not a list" "extraVolumeMounts" \
  --values "${work}/two-backups.yaml" --set-json 'backups.vaultSnapshot.extraVolumeMounts={"name":"x"}'

echo "==> all backup-utils checks passed"
