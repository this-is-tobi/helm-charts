#!/bin/bash
set -euo pipefail

# Completes a Renovate pull request with what Renovate cannot write itself, for each chart it changed:
# - artifacthub.io/changes: one entry for the new version, worded after the title of the pull request;
# - artifacthub.io/images: the image tagged with the previous appVersion follows the new appVersion.
# The README.md files helm-docs derives from Chart.yaml are regenerated next (helm-docs.sh --write).
# Idempotent: run on its own result, it changes nothing.
#
# Run from the repository, with PR_TITLE, PR_URL and BASE_REF (the base branch, fetched as origin/<BASE_REF>)
# describing the pull request. They come from a bot's branch, so they are data: they reach yq and awk
# through the environment only, never a command line or a YAML string written by this script.

: "${PR_TITLE:?}" "${PR_URL:?}" "${BASE_REF:?}"
cd "$(git rev-parse --show-toplevel)"

# "chore(searxng): update searxng to v2026.10.11" -> "Update searxng to v2026.10.11"
description="$(printf '%s' "${PR_TITLE}" | tr -d '[:cntrl:]' | sed -E 's/^[a-z]+(\([^)]*\))?!?: *//')"
description="${description:0:200}"
[ -n "${description}" ] || description="Update dependencies"
description="$(printf '%s' "${description:0:1}" | tr '[:lower:]' '[:upper:]')${description:1}"

# The entry as Artifact Hub reads it: yq quotes whatever the description holds.
changes="$(DESCRIPTION="${description}" LINK="${PR_URL}" yq -n \
  '[{"kind": "changed", "description": strenv(DESCRIPTION), "links": [{"name": "Pull Request", "url": strenv(LINK)}]}]')"

# Both blocks are rewritten as text: yq would re-indent every list of a Chart.yaml.
set_changes() {
  local chart_file="$1" tmp
  if ! grep -q '^  artifacthub.io/changes: |$' "${chart_file}"; then
    echo "ERROR: ${chart_file} has no artifacthub.io/changes block (\`artifacthub.io/changes: |\`) to update" >&2
    exit 1
  fi
  tmp="$(mktemp)"
  # shellcheck disable=SC2001 # a prefix on every line of a block, which ${var//a/b} cannot anchor
  BLOCK="$(sed 's/^/    /' <<<"${changes}")" awk '
    /^  artifacthub.io\/changes: \|$/ { print; print ENVIRON["BLOCK"]; skip = 1; next }
    skip && /^    / { next }
    { skip = 0; print }
  ' "${chart_file}" >"${tmp}"
  cat "${tmp}" >"${chart_file}"
  rm -f "${tmp}"
}

# The image of the chart is tagged with its appVersion: when that moves, the entry follows. An image pinned
# by digest is left alone, there is no digest to give it.
sync_images() {
  local chart_file="$1" base old new tmp
  if ! base="$(git show "origin/${BASE_REF}:${chart_file}" 2>/dev/null)"; then
    return 0
  fi
  old="$(yq '.appVersion' <<<"${base}")"
  new="$(yq '.appVersion' "${chart_file}")"
  if [ "${old}" = "${new}" ]; then
    return 0
  fi
  tmp="$(mktemp)"
  OLD=":${old}" NEW=":${new}" awk '
    /^  artifacthub.io\/images: \|$/ { in_images = 1; print; next }
    in_images && !/^    / { in_images = 0 }
    in_images && /^ +image: / && substr($0, length($0) - length(ENVIRON["OLD"]) + 1) == ENVIRON["OLD"] {
      $0 = substr($0, 1, length($0) - length(ENVIRON["OLD"])) ENVIRON["NEW"]
    }
    { print }
  ' "${chart_file}" >"${tmp}"
  cat "${tmp}" >"${chart_file}"
  rm -f "${tmp}"
}

while IFS= read -r chart_file; do
  [ -n "${chart_file}" ] || continue
  echo "==> ${chart_file}"
  set_changes "${chart_file}"
  if grep -q '^  artifacthub.io/images: |$' "${chart_file}"; then
    sync_images "${chart_file}"
  fi
done < <(git diff --name-only "origin/${BASE_REF}...HEAD" -- 'charts/*/Chart.yaml')
