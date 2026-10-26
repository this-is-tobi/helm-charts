#!/bin/bash
set -euo pipefail

# Checks renovate-post-upgrade.sh on a scratch repository seeded with a real Chart.yaml: a Renovate-like
# change of a chart is completed with the Artifact Hub changes and images, nothing else of the file moves,
# a second run changes nothing, and a hostile pull request title stays data.

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${SCRIPTS_DIR}/renovate-post-upgrade.sh"
FIXTURE="${SCRIPTS_DIR}/../../charts/searxng/Chart.yaml"
PR_URL="https://github.com/this-is-tobi/helm-charts/pull/1"
# The versions the scratch commits move the chart to. The chart is the real one, which Renovate keeps moving:
# they are values it can never hold, so a commit always changes something whatever the chart is on.
NEW_APP_VERSION="2099.1.1-0000000"
NEW_CHART_VERSION="99.0.0"
NEW_DEPENDENCY_VERSION="99.0.0"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

# What of Chart.yaml is neither of the two blocks the script rewrites.
without_blocks() {
  awk '
    /^  artifacthub.io\/(changes|images): \|$/ { skip = 1; next }
    skip && /^    / { next }
    { skip = 0; print }
  ' "$1"
}

# A scratch repository: the chart on main, then the commit Renovate would make (appVersion and version).
new_repo() {
  local dir="${WORK}/$1"
  mkdir -p "${dir}/charts/searxng"
  cp "${FIXTURE}" "${dir}/charts/searxng/Chart.yaml"
  git -C "${dir}" init -q -b main
  git -C "${dir}" config user.name test
  git -C "${dir}" config user.email test@example.com
  git -C "${dir}" add -A
  git -C "${dir}" commit -q -m base
  git -C "${dir}" update-ref refs/remotes/origin/main HEAD
  git -C "${dir}" switch -q -c renovate/searxng
  echo "${dir}"
}

# Commits what a sed changed in the scratch chart. A sed that matched nothing is the test being out of date, not a
# commit to skip.
commit_renovate() {
  local dir="$1"
  rm -f "${dir}/charts/searxng/Chart.yaml.bak"
  git -C "${dir}" diff --quiet && fail "the scratch change did not alter Chart.yaml: its lines are not those of the chart anymore"
  git -C "${dir}" commit -q -am renovate
}

renovate_commit() {
  local dir="$1" app_version="$2"
  sed -i.bak -e "s/^appVersion: .*/appVersion: \"${app_version}\"/" -e "s/^version: .*/version: ${NEW_CHART_VERSION}/" "${dir}/charts/searxng/Chart.yaml"
  commit_renovate "${dir}"
}

run() {
  local dir="$1" title="$2"
  (cd "${dir}" && PR_TITLE="${title}" PR_URL="${PR_URL}" BASE_REF=main "${SCRIPT}" >/dev/null)
}

chart() {
  echo "$1/charts/searxng/Chart.yaml"
}

echo "==> a Renovate change is completed: the changes of the new version, the image following appVersion"
repo="$(new_repo basic)"
renovate_commit "${repo}" "${NEW_APP_VERSION}"
without_blocks "$(chart "${repo}")" >"${WORK}/before.txt"
run "${repo}" "chore(searxng): update searxng to v${NEW_APP_VERSION}"
[ "$(yq '.annotations."artifacthub.io/changes" | from_yaml | length' "$(chart "${repo}")")" = 1 ] || fail "expected one changes entry"
[ "$(yq '.annotations."artifacthub.io/changes" | from_yaml | .[0].kind' "$(chart "${repo}")")" = changed ] || fail "kind is not changed"
[ "$(yq '.annotations."artifacthub.io/changes" | from_yaml | .[0].description' "$(chart "${repo}")")" = "Update searxng to v${NEW_APP_VERSION}" ] \
  || fail "description is not the title of the pull request"
[ "$(yq '.annotations."artifacthub.io/changes" | from_yaml | .[0].links[0].url' "$(chart "${repo}")")" = "${PR_URL}" ] || fail "no link to the pull request"
yq '.annotations."artifacthub.io/images" | from_yaml | .[].image' "$(chart "${repo}")" >"${WORK}/images.txt"
grep -qx "docker.io/searxng/searxng:${NEW_APP_VERSION}" "${WORK}/images.txt" || fail "the searxng image did not follow appVersion: $(cat "${WORK}/images.txt")"
grep -q '^docker.io/valkey/valkey:.*@sha256:' "${WORK}/images.txt" || fail "the digest-pinned valkey image was touched: $(cat "${WORK}/images.txt")"

echo "==> nothing else of Chart.yaml moves"
without_blocks "$(chart "${repo}")" >"${WORK}/after.txt"
diff "${WORK}/before.txt" "${WORK}/after.txt" || fail "Chart.yaml changed outside the changes and images blocks"

echo "==> a second run changes nothing"
cp "$(chart "${repo}")" "${WORK}/once.txt"
run "${repo}" "chore(searxng): update searxng to v${NEW_APP_VERSION}"
cmp -s "${WORK}/once.txt" "$(chart "${repo}")" || fail "a second run changed Chart.yaml"

echo "==> a dependency bump leaves the images annotation alone"
repo="$(new_repo dependency)"
sed -i.bak "s/^  version: .*/  version: ${NEW_DEPENDENCY_VERSION}/" "${repo}/charts/searxng/Chart.yaml"
commit_renovate "${repo}"
yq '.annotations."artifacthub.io/images"' "$(chart "${repo}")" >"${WORK}/images-before.txt"
run "${repo}" "chore(searxng): update valkey to v${NEW_DEPENDENCY_VERSION}"
yq '.annotations."artifacthub.io/images"' "$(chart "${repo}")" >"${WORK}/images-after.txt"
diff "${WORK}/images-before.txt" "${WORK}/images-after.txt" || fail "the images annotation moved with no appVersion change"

echo "==> a hostile title stays data"
repo="$(new_repo hostile)"
renovate_commit "${repo}" "${NEW_APP_VERSION}"
# shellcheck disable=SC2016 # the command substitution and the quotes are the point
hostile=$'chore(x): update `touch pwned` $(touch pwned) "quoted": \'single\' # not a comment\n- kind: security\n  description: injected\n{{ x }} %s'
run "${repo}" "${hostile}"
[ ! -e "${repo}/pwned" ] && [ ! -e pwned ] || fail "a command in the title was executed"
[ "$(yq '.annotations."artifacthub.io/changes" | from_yaml | length' "$(chart "${repo}")")" = 1 ] || fail "the title added an entry"
[ "$(yq '.annotations."artifacthub.io/changes" | from_yaml | .[0].kind' "$(chart "${repo}")")" = changed ] || fail "the title changed the kind"
# Control characters (the line breaks) are dropped, nothing else is: the rest comes back as it was.
# shellcheck disable=SC2016 # literal text, no expansion wanted
expected='Update `touch pwned` $(touch pwned) "quoted": '"'single'"' # not a comment- kind: security  description: injected{{ x }} %s'
[ "$(yq '.annotations."artifacthub.io/changes" | from_yaml | .[0].description' "$(chart "${repo}")")" = "${expected}" ] \
  || fail "the title did not come back as it was, control characters aside"

echo "==> a long title is cut"
repo="$(new_repo long)"
renovate_commit "${repo}" "${NEW_APP_VERSION}"
run "${repo}" "chore(searxng): update $(printf 'x%.0s' {1..400})"
[ "$(yq '.annotations."artifacthub.io/changes" | from_yaml | .[0].description | length' "$(chart "${repo}")")" -le 200 ] || fail "the description is longer than 200"

echo "==> a pull request that changes no chart changes nothing"
repo="$(new_repo untouched)"
echo "# a CI file" >"${repo}/ci.txt"
git -C "${repo}" add -A
git -C "${repo}" commit -q -m ci
cp "$(chart "${repo}")" "${WORK}/untouched.txt"
run "${repo}" "chore(deps): update a tool"
cmp -s "${WORK}/untouched.txt" "$(chart "${repo}")" || fail "a chart was changed by a pull request that did not touch one"

echo "==> a chart without a changes block is refused, not silently skipped"
repo="$(new_repo nochanges)"
awk '/^  artifacthub.io\/changes: \|$/ { skip = 1; next } skip && /^    / { next } { skip = 0; print }' "${repo}/charts/searxng/Chart.yaml" >"${WORK}/nochanges.txt"
cp "${WORK}/nochanges.txt" "${repo}/charts/searxng/Chart.yaml"
git -C "${repo}" commit -q -am "drop changes"
git -C "${repo}" update-ref refs/remotes/origin/main HEAD
renovate_commit "${repo}" "${NEW_APP_VERSION}"
if output="$(cd "${repo}" && PR_TITLE="chore: x" PR_URL="${PR_URL}" BASE_REF=main "${SCRIPT}" 2>&1)"; then
  fail "a chart without a changes block was accepted"
fi
grep -q 'has no artifacthub.io/changes block' <<<"${output}" || fail "refused, but not for the expected reason: ${output}"

echo "==> all checks passed"
