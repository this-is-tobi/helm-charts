#!/bin/bash
set -euo pipefail

# Checks update-helm-index.sh against a local registry that speaks what ghcr.io speaks for a Helm package (anonymous
# token, tags in pages, manifest, config blob): every version of a chart becomes an entry that points at the registry,
# what is not a chart version is left out, an entry already in the index is not touched, a second run changes nothing,
# and a package that cannot be trusted stops the run without touching the index.

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${SCRIPTS_DIR}/update-helm-index.sh"
REPOSITORY="acme/charts"
WORK="$(mktemp -d)"
REGISTRY_PID=""

cleanup() {
  if [ -n "${REGISTRY_PID}" ]; then
    kill "${REGISTRY_PID}" 2> /dev/null || true
    wait "${REGISTRY_PID}" 2> /dev/null || true
  fi
  rm -rf "${WORK}"
}
trap cleanup EXIT

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

expect() {
  [ "$2" = "$3" ] || fail "$1: expected '$3', got '$2'"
}

# The registry. The packages:
#   alpha    1.0.0 1.1.0 2.0.0-rc.1 2.0.0, with tags that are not versions (latest, a cosign signature, an attestation),
#            more tags than a page holds
#   beta     0.1.0
#   liar     a tag whose config says another version
#   private  no anonymous token
#   signed   nothing but the tags of a cosign signature and an attestation
# The layer of a chart is never served: an index entry needs its digest, which the manifest has.
cat > "${WORK}/registry.py" << 'PYTHON'
import hashlib, http.server, json, sys, urllib.parse

REPOSITORY = "acme/charts"
HELM_CONFIG = "application/vnd.cncf.helm.config.v1+json"
HELM_CHART = "application/vnd.cncf.helm.chart.content.v1.tar+gzip"
HELM_PROV = "application/vnd.cncf.helm.chart.provenance.v1.prov"
SIGNATURE = "sha256-" + "a" * 64
PAGE_SIZE = 3
CHARTS = {
    "alpha": ["1.0.0", "1.1.0", "2.0.0-rc.1", "2.0.0", "latest", SIGNATURE + ".sig", SIGNATURE],
    "beta": ["0.1.0"],
    "liar": ["1.0.0"],
    "private": ["1.0.0"],
    "signed": [SIGNATURE + ".sig", SIGNATURE],
}


def sha(data):
    return "sha256:" + hashlib.sha256(data).hexdigest()


def layer_digest(chart, version):
    return sha(f"{chart}-{version}".encode())


def config(chart, version):
    # `liar:1.0.0` is a package whose config describes another version.
    if chart == "liar":
        version = "9.9.9"
    return {
        "apiVersion": "v2",
        "name": chart,
        "version": version,
        "description": f"The {chart} chart",
        "type": "application",
        "keywords": [chart],
        "maintainers": [{"name": "tester", "email": "tester@example.com"}],
        "annotations": {"artifacthub.io/changes": "- kind: added\n  description: \"a line\"\n"},
    }


def config_bytes(chart, version):
    return json.dumps(config(chart, version), sort_keys=True).encode()


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        with open(sys.argv[2], "a") as log:
            log.write(self.path + "\n")

    def reply(self, status, body=b"", headers=None):
        self.send_response(status)
        for name, value in (headers or {}).items():
            self.send_header(name, value)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def json(self, status, document, headers=None):
        self.reply(status, json.dumps(document).encode(), headers)

    def do_GET(self):
        url = urllib.parse.urlparse(self.path)
        query = urllib.parse.parse_qs(url.query)

        if url.path == "/token":
            scope = query.get("scope", [""])[0]
            # The token of a package that is not public is an empty answer, as ghcr.io's is.
            return self.json(200, {} if scope.startswith(f"repository:{REPOSITORY}/private:") else {"token": "anonymous"})

        if self.headers.get("Authorization") != "Bearer anonymous":
            return self.json(401, {"errors": [{"code": "UNAUTHORIZED"}]})

        parts = url.path.split("/")  # "", "v2", "acme", "charts", chart, kind, reference
        if len(parts) != 7 or "/".join(parts[2:4]) != REPOSITORY or parts[4] not in CHARTS:
            return self.json(404, {"errors": [{"code": "NOT_FOUND"}]})
        chart, kind, reference = parts[4], parts[5], parts[6]

        if kind == "tags" and reference == "list":
            tags = sorted(CHARTS[chart])
            last = query.get("last", [None])[0]
            if last is not None:
                tags = [tag for tag in tags if tag > last]
            page, rest = tags[:PAGE_SIZE], tags[PAGE_SIZE:]
            headers = {}
            if rest:
                headers["Link"] = f'</v2/{REPOSITORY}/{chart}/tags/list?last={page[-1]}&n=1000>; rel="next"'
            return self.json(200, {"name": f"{REPOSITORY}/{chart}", "tags": page}, headers)

        if kind == "manifests" and reference in CHARTS[chart]:
            data = config_bytes(chart, reference)
            return self.json(200, {
                "schemaVersion": 2,
                "config": {"mediaType": HELM_CONFIG, "digest": sha(data), "size": len(data)},
                "layers": [
                    {"mediaType": HELM_CHART, "digest": layer_digest(chart, reference), "size": 1},
                    {"mediaType": HELM_PROV, "digest": sha(b"prov"), "size": 1},
                ],
                "annotations": {"org.opencontainers.image.created": "2026-01-01T00:00:00Z"},
            })

        if kind == "blobs":
            for version in CHARTS[chart]:
                if reference == sha(config_bytes(chart, version)):
                    return self.reply(200, config_bytes(chart, version))
        return self.json(404, {"errors": [{"code": "NOT_FOUND"}]})


server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
with open(sys.argv[1], "w") as port_file:
    port_file.write(str(server.server_address[1]))
server.serve_forever()
PYTHON

start_registry() {
  : > "${WORK}/requests.log"
  python3 -I "${WORK}/registry.py" "${WORK}/port" "${WORK}/requests.log" &
  REGISTRY_PID=$!
  local waited=0
  until [ -s "${WORK}/port" ]; do
    waited=$((waited + 1))
    [ "${waited}" -lt 50 ] || fail "the local registry did not start"
    sleep 0.1
  done
  PORT="$(cat "${WORK}/port")"
}

# The script under test, pointed at the local registry.
update_index() {
  REGISTRY="127.0.0.1:${PORT}" REGISTRY_URL="http://127.0.0.1:${PORT}" REPOSITORY="${REPOSITORY}" "${SCRIPT}" "$@"
}

versions() {
  yq ".entries.\"$2\" | map(.version) | join(\" \")" "$1"
}

start_registry

echo "- a new index gets every version of the charts, newest first"
update_index "${WORK}/index.yaml" alpha beta 2> /dev/null
expect "versions of alpha" "$(versions "${WORK}/index.yaml" alpha)" "2.0.0 2.0.0-rc.1 1.1.0 1.0.0"
expect "versions of beta" "$(versions "${WORK}/index.yaml" beta)" "0.1.0"
expect "charts in the index" "$(yq '.entries | keys | join(" ")' "${WORK}/index.yaml")" "alpha beta"

echo "- an entry points at the registry and carries what the package carries"
expect "url" "$(yq '.entries.alpha[0].urls[0]' "${WORK}/index.yaml")" "oci://127.0.0.1:${PORT}/${REPOSITORY}/alpha:2.0.0"
expect "digest" "$(yq '.entries.alpha[0].digest' "${WORK}/index.yaml")" "$(printf '%s' 'alpha-2.0.0' | shasum -a 256 | cut -d' ' -f1)"
expect "created" "$(yq '.entries.alpha[0].created' "${WORK}/index.yaml")" "2026-01-01T00:00:00Z"
expect "description" "$(yq '.entries.alpha[0].description' "${WORK}/index.yaml")" "The alpha chart"
expect "multi-line annotation" "$(yq '.entries.alpha[0].annotations["artifacthub.io/changes"]' "${WORK}/index.yaml" | sed -n 1p)" "- kind: added"

echo "- the layer of a chart is never downloaded"
layer_hex="$(printf '%s' 'alpha-2.0.0' | shasum -a 256 | cut -d' ' -f1)"
if grep -q "blobs/sha256:${layer_hex}" "${WORK}/requests.log"; then
  fail "the chart layer was requested"
fi

echo "- a second run changes nothing"
cp "${WORK}/index.yaml" "${WORK}/index.before"
update_index "${WORK}/index.yaml" alpha beta 2> /dev/null
cmp -s "${WORK}/index.yaml" "${WORK}/index.before" || fail "a run that had nothing to add rewrote the index"

echo "- an entry that is already there is left as it is, a chart of the index that is not asked for stays"
cat > "${WORK}/classic.yaml" << 'YAML'
apiVersion: v1
entries:
  alpha:
  - apiVersion: v2
    created: "2020-01-01T00:00:00Z"
    digest: aaaa
    name: alpha
    urls:
    - https://github.com/acme/charts/releases/download/alpha-1.0.0/alpha-1.0.0.tgz
    version: 1.0.0
  gamma:
  - apiVersion: v2
    created: "2020-01-01T00:00:00Z"
    digest: gggg
    name: gamma
    urls:
    - https://github.com/acme/charts/releases/download/gamma-0.0.1/gamma-0.0.1.tgz
    version: 0.0.1
generated: "2020-01-01T00:00:00Z"
YAML
update_index "${WORK}/classic.yaml" alpha beta 2> /dev/null
expect "versions of alpha" "$(versions "${WORK}/classic.yaml" alpha)" "2.0.0 2.0.0-rc.1 1.1.0 1.0.0"
expect "url of the version already there" "$(yq '.entries.alpha[] | select(.version == "1.0.0") | .urls[0]' "${WORK}/classic.yaml")" \
  "https://github.com/acme/charts/releases/download/alpha-1.0.0/alpha-1.0.0.tgz"
expect "digest of the version already there" "$(yq '.entries.alpha[] | select(.version == "1.0.0") | .digest' "${WORK}/classic.yaml")" "aaaa"
expect "chart that is not asked for" "$(versions "${WORK}/classic.yaml" gamma)" "0.0.1"
expect "url of a new version" "$(yq '.entries.alpha[] | select(.version == "1.1.0") | .urls[0]' "${WORK}/classic.yaml")" \
  "oci://127.0.0.1:${PORT}/${REPOSITORY}/alpha:1.1.0"

echo "- a package with nothing but signatures adds nothing"
update_index "${WORK}/signed.yaml" signed 2> /dev/null
expect "charts in the index" "$(yq '.entries | length' "${WORK}/signed.yaml")" "0"

echo "- a tag that holds another version stops the run and leaves the index alone"
cp "${WORK}/classic.yaml" "${WORK}/classic.before"
if update_index "${WORK}/classic.yaml" beta liar 2> "${WORK}/error.log"; then
  fail "a package whose config is not its tag was accepted"
fi
grep -q "liar:1.0.0 holds liar 9.9.9" "${WORK}/error.log" || fail "the error does not name the package: $(cat "${WORK}/error.log")"
cmp -s "${WORK}/classic.yaml" "${WORK}/classic.before" || fail "a failed run changed the index"

echo "- a package that is not public stops the run and says so"
if update_index "${WORK}/classic.yaml" private 2> "${WORK}/error.log"; then
  fail "a package without an anonymous token was accepted"
fi
grep -q "is the package public" "${WORK}/error.log" || fail "the error does not tell the package has to be public: $(cat "${WORK}/error.log")"
cmp -s "${WORK}/classic.yaml" "${WORK}/classic.before" || fail "a failed run changed the index"

echo "all checks passed"
