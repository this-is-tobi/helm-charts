#!/bin/bash
set -euo pipefail

HELM_DOCS_VERSION="1.14.2"

# Generates the README.md of every chart, for the caller to commit (the check that they are up to date is the shared
# lint-helm workflow's).
#
# helm-docs is built from source at exactly that version: `go install` checks the module against the Go checksum
# database, which a release tarball is not. It is stamped as the release is, as the footer of a README names the
# version and an unstamped build would rewrite it.
go install -trimpath -ldflags "-s -w -X main.version=${HELM_DOCS_VERSION}" "github.com/norwoodj/helm-docs/cmd/helm-docs@v${HELM_DOCS_VERSION}"
"$(go env GOPATH)/bin/helm-docs"
