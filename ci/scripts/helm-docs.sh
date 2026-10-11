#!/bin/bash
set -euo pipefail

HELM_DOCS_VERSION="1.14.2"

# install helm-docs
curl --silent --show-error --fail --location --output /tmp/helm-docs.tar.gz https://github.com/norwoodj/helm-docs/releases/download/v"${HELM_DOCS_VERSION}"/helm-docs_"${HELM_DOCS_VERSION}"_Linux_x86_64.tar.gz
tar -xf /tmp/helm-docs.tar.gz helm-docs

# generate the docs, then validate them: with --write, leave them generated for the caller to commit
./helm-docs
[ "${1:-}" = "--write" ] || git diff --exit-code
