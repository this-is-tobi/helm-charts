#!/bin/bash
set -euo pipefail

# Completes a Helm repository index with the chart versions an OCI registry holds and the index does not list yet.
# The entries it adds point at the registry (oci://<registry>/<repository>/<chart>:<version>): Helm and Artifact Hub
# follow such a URL, so the index stays the one address of the Helm repository while the registry is where the packages
# are. Every entry already in the index is left as it is, whatever its URL (the first versions were GitHub Releases).
#
# An entry is rebuilt from the registry alone, with nothing downloaded but the manifest and its config:
#   - the config blob of a Helm package is its Chart.yaml as JSON, which is what an entry holds;
#   - the digest of the chart layer is the sha256 of the .tgz, which is the `digest` of an entry (checked against the
#     digest the chart-releaser entry of the same version has);
#   - `created` is the creation date the package was pushed with.
#
# The registry is read anonymously, so its packages have to be public. Only ghcr.io is supported (its token endpoint).
#
# Usage: update-helm-index.sh <index.yaml> <chart>...
#   The index is created when the file does not exist. It is rewritten only when an entry is added, so a run that
#   finds nothing new leaves it byte for byte as it was.
#
# Environment:
#   REGISTRY     registry host, written in the urls (default: ghcr.io)
#   REPOSITORY   path of the charts in the registry (default: this-is-tobi/charts)
#   REGISTRY_URL base URL of the registry API (default: https://${REGISTRY}); the tests point it at a local server

REGISTRY="${REGISTRY:-ghcr.io}"
REPOSITORY="${REPOSITORY:-this-is-tobi/charts}"
REGISTRY_URL="${REGISTRY_URL:-https://${REGISTRY}}"

# What a chart version looks like as a tag. Anything else under a package is not a chart: the cosign signatures
# (sha256-<digest>.sig), the attestations (sha256-<digest>) and whatever is tagged by hand.
SEMVER_TAG='^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$'
HELM_CONFIG_MEDIA_TYPE="application/vnd.cncf.helm.config.v1+json"
HELM_CHART_MEDIA_TYPE="application/vnd.cncf.helm.chart.content.v1.tar+gzip"
MANIFEST_ACCEPT="application/vnd.oci.image.manifest.v1+json"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

registry_get() {
  curl --fail --silent --show-error --location --retry 3 --header "Authorization: Bearer ${TOKEN}" "$@"
}

# Every tag of a package, following the pages the registry cuts the list into.
list_tags() {
  local path="$1" url headers
  url="${REGISTRY_URL}/v2/${path}/tags/list?n=1000"
  headers="${WORK}/headers"
  while [ -n "${url}" ]; do
    registry_get --dump-header "${headers}" "${url}" | jq -r '.tags[]?'
    # The Link header is relative to the registry: `</v2/<path>/tags/list?last=<tag>&n=1000>; rel="next"`.
    url="$(sed -n 's/^[Ll]ink: <\(.*\)>; rel="next".*/\1/p' "${headers}" | tr -d '\r')"
    case "${url}" in
      /*) url="${REGISTRY_URL}${url}" ;;
    esac
  done
}

# The entry of one version, as a JSON object on one line, built from the registry.
build_entry() {
  local path="$1" chart="$2" tag="$3" manifest config_digest layer_digest created
  manifest="${WORK}/manifest.json"
  registry_get --header "Accept: ${MANIFEST_ACCEPT}" "${REGISTRY_URL}/v2/${path}/manifests/${tag}" > "${manifest}"

  [ "$(jq -r '.config.mediaType' "${manifest}")" = "${HELM_CONFIG_MEDIA_TYPE}" ] \
    || fail "${chart}:${tag} is not a Helm chart (config media type $(jq -r '.config.mediaType' "${manifest}"))"
  config_digest="$(jq -r '.config.digest' "${manifest}")"
  layer_digest="$(jq -r --arg type "${HELM_CHART_MEDIA_TYPE}" '[.layers[] | select(.mediaType == $type)][0].digest // empty' "${manifest}")"
  [ -n "${layer_digest}" ] || fail "${chart}:${tag} has no chart layer"
  created="$(jq -r '.annotations["org.opencontainers.image.created"] // empty' "${manifest}")"

  registry_get "${REGISTRY_URL}/v2/${path}/blobs/${config_digest}" > "${WORK}/config.json"
  # A tag that holds another chart, or another version, would put a wrong entry in the index for good.
  jq -e --arg name "${chart}" --arg version "${tag}" '.name == $name and .version == $version' "${WORK}/config.json" > /dev/null \
    || fail "${chart}:${tag} holds $(jq -r '.name + " " + .version' "${WORK}/config.json")"

  jq -c \
    --arg created "${created:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}" \
    --arg digest "${layer_digest#sha256:}" \
    --arg url "oci://${REGISTRY}/${path}:${tag}" \
    '. + {created: $created, digest: $digest, urls: [$url]}' "${WORK}/config.json"
}

main() {
  [ "$#" -ge 2 ] || fail "usage: $0 <index.yaml> <chart>..."
  local index="$1" chart path tag
  shift

  [ -f "${index}" ] || printf 'apiVersion: v1\nentries: {}\n' > "${index}"
  yq -o=json '.' "${index}" > "${WORK}/index.json"
  : > "${WORK}/new-entries.jsonl"

  for chart in "$@"; do
    path="${REPOSITORY}/${chart}"
    TOKEN="$(curl --fail --silent --show-error --retry 3 "${REGISTRY_URL}/token?scope=repository:${path}:pull" | jq -r '.token // empty')"
    [ -n "${TOKEN}" ] || fail "no anonymous token for ${path}: is the package public?"

    # A chart may be in the registry with no version in the index yet (a new chart), and the other way round (the
    # versions chart-releaser listed before the registry had the chart): only the first is this script's.
    list_tags "${path}" | { grep -E "${SEMVER_TAG}" || true; } | while read -r tag; do
      if jq -e --arg name "${chart}" --arg version "${tag}" '(.entries[$name] // []) | any(.version == $version)' "${WORK}/index.json" > /dev/null; then
        continue
      fi
      echo "adding ${chart} ${tag}" >&2
      build_entry "${path}" "${chart}" "${tag}" >> "${WORK}/new-entries.jsonl"
    done
  done

  if [ ! -s "${WORK}/new-entries.jsonl" ]; then
    echo "the index is complete: nothing to add" >&2
    return 0
  fi

  # The file is written by Helm: `helm repo index` on an empty directory, merged with the entries, writes the index as
  # chart-releaser does (same layout, versions sorted newest first by semver), so that the lines of the entries already
  # there do not move and a commit of the index shows the new versions only.
  jq --slurpfile added "${WORK}/new-entries.jsonl" \
    '.entries = (reduce $added[] as $entry (.entries // {}; .[$entry.name] += [$entry]))' "${WORK}/index.json" > "${WORK}/merged.json"
  mkdir "${WORK}/empty"
  helm repo index "${WORK}/empty" --merge "${WORK}/merged.json"
  mv "${WORK}/empty/index.yaml" "${index}"
}

main "$@"
