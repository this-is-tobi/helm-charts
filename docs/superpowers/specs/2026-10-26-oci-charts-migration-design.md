# One home for every chart: migration to `ghcr.io/this-is-tobi/charts`

Status: in progress, updated 2026-11-03 (drafted 2026-10-26). Spans helm-charts, github-workflows, rta, ohmlab (the
former homelab) and template-monorepo-ts. "Progress" says what is done and what changed from the plan; the sections
below are the plan as it was drafted, corrected where the registry proved it wrong.

## Progress (2026-11-03)

Done:

- **ohmlab**: `charts/ohmlab` since 2026-10-29. Its 29 older versions were copied by digest and verified, and the old
  packages were deleted by the owner on 2026-11-02.
- **rta**: `charts/rta` 0.43.0 was published and signed on 2026-11-03 (rta#437 and rta#438). The chart is renamed `rta`; an existing release adds `nameOverride: rta-chart`, which renders what `rta-chart` 0.42.1 renders, object for object. The first push failed once on a transient GHCR 404 after the upload (`failed to perform "Tag" on destination`, Helm 4 fetches the manifest back by digest to tag it); re-running the failed jobs fixed it.
- **helm-charts, the copy**: the 102 versions of the seven old packages are at `charts/*` (the owner ran the script on 2026-11-03). The six new packages are public and linked to this repository, and the anonymous check finds, for every version, the same manifest digest, the same referrer digests and a signature that verifies as it did before.
- **helm-charts, step 2**: helm-charts#140 was merged the same day. Its release pushed backup-utils 2.5.8, cnpg-cluster 2.3.1, homepage 0.2.1, searxng 0.3.1, system-upgrade-controller 0.1.1 and vso-utils 2.2.1 to `charts/*` and attested them, and an anonymous check of the six passes: the cosign signature, the SLSA provenance and `helm pull --verify` against the GPG key.

What changed from the plan:

- Step 1 (the spike) is dropped: the ohmlab move and rta's first release answered what it was for. `oras copy -r` keeps
  the digest, the signature and the provenance. A package created by a workflow is linked to its repository and writable
  by it; a package made by hand is neither, and needs the repository under "Manage Actions access", and a change of
  visibility to be pulled anonymously.
- The copy of the helm-charts versions is a script the owner runs with their own token (dry run by default, safe to
  re-run), not a pull-request workflow that is never merged. It also copies the cosign 2 `sha256-<digest>.sig` tag of
  the 23 older versions, which `oras copy -r` leaves behind. A second script checks anonymously, for every version, that
  the digest, the referrers and the signature are the same at both ends.
- helm-charts has 55 released versions in OCI, not 51: backup-utils 23, cnpg-cluster 14, vso-utils 11, searxng 4,
  homepage 2, system-upgrade-controller 1. 48 are signed by a workflow and 7 by the maintainer by hand (backup-utils
  2.2.0 to 2.2.2, cnpg-cluster 1.5.0 and 1.5.1, vso-utils 1.1.0 and 1.1.1).
- **rta's 47 older versions are copied too** (the owner's call, 2026-11-03; the plan below kept them at `rta/rta-chart`). They go by digest with their signatures, like the others, and still carry `name: rta-chart` inside: a release moving to `charts/rta` at the same version keeps its object names, and `nameOverride: rta-chart` is needed once it upgrades to 0.43.0 or later. One script copies the seven packages, 102 versions (all 47 of rta are signed by a workflow, none with a cosign 2 signature), and a second one verifies them.
- **A release that fails.** The shared release workflows (github-workflows v0.47.0, pinned here by #142) push each chart up to three times, 15 and 30 seconds apart, and write `published-charts` however the step ends. Before that, a failure on the third of six charts left the first two published and never listed: the attest job was skipped, and the re-run found their versions in the registry and left them out for good. In helm-charts#140 the `attest` job runs after a failed release (`if: ${{ !cancelled() }}`). The copy also removes the first-push case, since the six packages exist by then.
- **chart-releaser's own OCI push was read and not adopted.** `cr push` (chart-releaser v1.9.0, `oci_registry_url` in the action since v1.8.0) runs the same Helm push code, without a retry, and prints no machine-readable digest for `attest-helm.yml`.
- **The GPG `.prov` file already travels to OCI.** `helm push` sends the file found beside a package as an extra layer, so `helm pull --verify oci://…` checks the GPG signature: 52 of the 55 helm-charts versions have it (not backup-utils 2.2.0, cnpg-cluster 1.5.0, vso-utils 1.1.0). The workflow notes saying the opposite are corrected.
- Step 2 goes in an order that matters: copy, package access (public, and `helm-charts` with the Write role), verify,
  then merge the pull request that sets `REPOSITORY: this-is-tobi/charts`. `SKIP_EXISTING` looks at the destination:
  merged before the copy, a chart that changed without a version bump would be pushed again under a new digest.

Later, on the owner's call:

- Steps 4 (our consumers leave the classic Helm repository), 5 (Artifact Hub) and 6 (the classic repository retires).
- **Cleaning the old OCI packages, `rta/rta-chart` and the six `helm-charts/<chart>`, much later, once people have
  migrated.** The owner thinks nobody consumes the OCI charts; the download counts of the packages, on their pages,
  would say before anything is deleted. Every version of the seven old packages is at the new path by then, so nothing
  is lost once the copy is verified (GitHub restores a deleted package for 30 days, only while its name is unused).
- **Step 6, what the survey of 2026-11-03 adds.** (a) Helm follows an `oci://` URL in a classic `index.yaml` (tested with Helm 4.3.1: `helm repo add` on a static index, then `helm pull` of `charts/rta:0.43.0`), so `helm repo add` can outlive chart-releaser on a static index whose entries point at the registry. (b) Dropping chart-releaser ends the GPG signature, since only it signs, unless the OCI-only path learns `helm package --sign`. (c) Stopping only the public index needs no code: chart-releaser keeps running with `PAGES_BRANCH` on a branch nobody serves (docs/51-release-helm.md of github-workflows, option 2), and releases, tags and signatures go on. (d) Artifact Hub registers an OCI chart per repository (`oci://registry/ns/chart`): step 5 makes 8 (6 + rta + ohmlab), where one classic repository lists the six today.

## Intent

Charts are published today from three repositories, to three OCI paths, through two channels, with two signing schemes,
and Artifact Hub sees only part of them. Every new chart repeats that choice. The goal is one source of truth, so that
there is less to maintain: one registry path, one pipeline, one channel, one catalog.

There are two kinds of charts, and their sources stay where they are:

- **Charts of other people's software**, packaged by us: they live in `helm-charts`, and Renovate follows the image.
- **Charts of our own apps**: they live in the app's repository, and the app's pipeline releases them with the app.

What gets unified is how charts are shipped, not where they are written.

## Goals

- Every chart is published at `oci://ghcr.io/this-is-tobi/charts/<chart>`, whatever repository builds it.
- Every repository publishes through the same shared workflows of `this-is-tobi/github-workflows`
  (release, then `attest-helm.yml` for the cosign signature and the provenance).
- Every consumer in our repositories installs from that path.
- Later: Artifact Hub reads every chart from that path, and becomes the catalog.
- Last: the classic Helm repository (`https://this-is-tobi.github.io/helm-charts`), its GitHub Releases and the GPG
  signature stop being maintained. Whether this step happens depends on the outside consumers (see the open question).

## Non-goals

- Moving app charts into `helm-charts`, or product charts into app repositories.
- Changing what a chart deploys. No template change is part of this migration.
- Backfilling into OCI the old versions that only exist in the classic Helm repository.
- The `homelab/argo-cd/apps/*` charts (deployment wrappers, never published) and the `homelab/catalog` bundle (not a chart).
- Charts that publish nothing today: `docs/helm`, `fastify-ws`, `github-ci-tests*`.

## Anti-goals (a failure even if it works)

- A published version changes content. A consumer pins a version and the signature is bound to the digest: versions are
  **copied by digest**, never pushed again from a fresh package.
- An old path stops working. `helm-charts/<chart>`, `rta/rta-chart` and `homelab/charts/ohmlab` are frozen, never deleted. GHCR has no redirect or alias between packages, so the frozen package, holding the same digests as the new one, is the only bridge.
- A deployed rta release loses its volume or secrets when it upgrades to the renamed chart (see "Chart names").
- `this-is-tobi` details leak into github-workflows: its workflows stay generic, the path is passed by the callers.

## Current state (2026-10-26)

| Chart | Kind | Built in | Published at (`ghcr.io/this-is-tobi/…`) | Versions in OCI | Artifact Hub |
|---|---|---|---|---|---|
| searxng, homepage, system-upgrade-controller | other people's software | helm-charts | `helm-charts/<chart>` | 3, 1, 1 | yes, through the classic Helm repository |
| cnpg-cluster, vso-utils | resources for other people's operators | helm-charts | `helm-charts/<chart>` | 14, 10 | yes, same |
| backup-utils | our own `tools/backup` image, followed by Renovate | helm-charts | `helm-charts/backup-utils` | 22 | yes, same |
| rta-chart | our app | rta | `rta/rta-chart` | 39 | no |
| ohmlab | our app (bootstrap chart) | homelab, `utils/helm` | `homelab/charts/ohmlab` | 9 | no |
| template-monorepo-ts | template app | template-monorepo-ts, `helm` | nothing yet | 0 | no |

- **Two channels for the helm-charts charts.** `release.yaml` calls `release-helm.yml` (chart-releaser): GitHub Releases
  plus the classic Helm repository on `gh-pages` (GPG-signed), and OCI (cosign keyless plus provenance, by
  `attest-helm.yml`). The classic Helm repository holds more versions than OCI (backup-utils 48 against 22, cnpg-cluster
  44 against 14, vso-utils 12 against 10), and still lists the removed dashy and homarr.
- **The app repositories** call `update-helm-chart.yml` (local mode in rta, release-please in homelab), then
  `release-helm-local.yml` and `attest-helm.yml`. template-monorepo-ts calls `update-helm-chart.yml` (called mode, a PR)
  then `release-helm.yml`, although it is a monorepo. Nothing calls `dispatch-helm-chart.yml`.
- **Every consumer of ours uses the classic Helm repository, none uses an OCI path of helm-charts.** In homelab, about
  two dozen `Chart.yaml` files (find them with `grep -l 'github.io/helm-charts'`, `utils/helm` included): vso-utils 2.1.0
  (x21), homepage 0.1.0, system-upgrade-controller 0.1.0, backup-utils 2.5.6. In template-monorepo-ts, cnpg-cluster
  2.3.0 (x2). All these versions exist in OCI.
- **Consumers outside our repositories exist.** `gh search code` (2026-10-26) finds pins on the classic Helm repository in
  IA-Generative (`mirai-infra`, `chart-open-webui`, `n8n-observability-infra`, `MyMirai`) and dnum-mi (`sdid-infra-k8s-app`),
  for instance cnpg-cluster 1.5.3 and 2.0.0 and searxng 0.2.x. The docs of `dnum-mi/starter-kit-opencode` send readers to
  `oci://ghcr.io/this-is-tobi/helm-charts`, and `lynh7/home-cluster` carries a copy of the cnpg-cluster README. See the
  open question.
- **Signatures in the registry.** Recent versions have OCI referrers, under the fallback tag `sha256-<digest>` (cosign 3
  bundle, `attest-build-provenance` with `push-to-registry`). The older versions have only a cosign 2 tag
  `sha256-<digest>.sig` and no referrer: 11 in backup-utils, 5 in cnpg-cluster, 7 in vso-utils (23 in all). Of those, at
  least vso-utils 1.1.1 is signed by a person, not a workflow (`this-is-tobi@proton.me`, issuer
  `https://github.com/login/oauth`), and the subagent review found six more: cnpg-cluster 1.5.0 and 1.5.1, vso-utils 1.1.0,
  backup-utils 2.2.0, 2.2.1 and 2.2.2 (re-checked on 2026-11-03: all seven are signed by the maintainer, vso-utils 1.1.0
  included, and no version of the six charts is unsigned).
  The README's identity regexp accepts both the old workflow identity
  (`helm-charts/.github/workflows/release.yaml@refs/heads/main`) and the shared one
  (`github-workflows/.github/workflows/attest-helm.yml@.+`), and none of these personal signatures.
- **`release-helm.yml` no longer needs chart-releaser to publish to OCI.** Since github-workflows v0.43.1 (commit
  `f174948`, 2026-10-17), `CREATE_GITHUB_RELEASE: false` skips chart-releaser: a step packages the charts that changed
  since the latest tag (or since the first commit when there is none), `SKIP_EXISTING` leaves published versions alone, and
  a run with nothing to publish returns `[]`. helm-charts pins v0.44.1.
- **First-time ghcr packages start private.** The homelab `cd.yml` says so ("Re-run this job alone once a first-time
  package has been made public").
- **Artifact Hub** indexes the classic Helm repository only (`this-is-tobi-helm-charts`, owner `tobi-or-not`). For OCI it
  takes **one Artifact Hub repository per chart**, URL `oci://registry/namespace/chart-name`. Its metadata
  (`artifacthub-repo.yml`, with that repository's own `repositoryID`) is pushed with oras under the tag `artifacthub.io`.

## Target state

- **Path.** `oci://ghcr.io/this-is-tobi/charts/<chart>`. A chart name is unique across all repositories.
  The ghcr package `charts/<chart>` belongs to the repository that builds the chart.
- **Where a chart lives.** With its software when the app's own pipeline releases both together (rta, ohmlab,
  template-monorepo-ts). Otherwise in helm-charts, and Renovate follows the image. backup-utils stays in helm-charts.
- **Pipeline.** A shared release workflow, then `attest-helm.yml` (cosign plus provenance), with
  `REPOSITORY: this-is-tobi/charts`. Nothing else signs a chart. The release workflow is `release-helm-local.yml` in a
  repository that holds one chart next to an app (rta, homelab, template-monorepo-ts), and `release-helm.yml` in OCI-only
  mode (`CREATE_GITHUB_RELEASE: false`) in helm-charts, which holds several charts and has its own tags.
- **Channel.** OCI only, at the end of step 6 (if the outside consumers allow it).
- **Catalog.** Artifact Hub, fed by each chart's own metadata (`Chart.yaml` annotations, README, `artifacthub-repo.yml`
  next to `Chart.yaml`). Until step 5, the helm-charts README lists the charts built in other repositories.

## Chart names

The path is `charts/<name>`, where `<name>` is the `name:` of `Chart.yaml`, so every chart is named for what it deploys,
with no `-chart` suffix. Only `rta-chart` departs from that: it is renamed **`rta`**, and its directory moves from
`charts/rta-chart` to `charts/rta` so that the directory, the chart name and the OCI path agree.

The rename has a cost in the chart. `rta.fullname` and the selector labels are built from `.Chart.Name`, and the chart
creates a Deployment, Services, Secrets and a PersistentVolumeClaim per server. With the release `rta` and the server
`tobi`, the resources are today `rta-rta-chart-tobi` and become `rta-tobi`. `helm upgrade` of an existing release to the
renamed chart would therefore create new resources and delete the old ones, and the PersistentVolumeClaim (the instance's
persistent state, with no keep policy by default) would be replaced by an empty one.

The way out is already in the chart: `nameOverride: rta-chart` makes the new chart render the same names as the old one
(`rta.name` is `nameOverride | default .Chart.Name`). New installs get the clean names, and existing releases add that one
value before they upgrade. The upgrade note says so (see step 3), and a check proves it (the resources of the old chart
and of the new chart with the override carry the same names).

The old versions of `rta-chart` carry that name inside the package. They are copied to `charts/rta` all the same (see "Progress"), so the history is in one place: up to 0.42.1 they render the old names, and 0.43.0 is the first that needs the override.

## How a version moves (used in steps 1 to 3)

For each version tag of the old package:

1. `oras cp -r <old>/<chart>:<version> <new>/<chart>:<version>` copies the manifest unchanged (same digest) along with
   its referrers: the cosign 3 signature and the provenance.
2. When the old package has `sha256-<digest>.sig`, copy that tag too (`oras cp`). `cosign copy` is the alternative.
3. Check the destination: same digest as the source, `cosign verify` with the README's identity regexp, and
   `cosign verify-attestation --type slsaprovenance1` when the version has a provenance.
4. The versions signed by a person (see "Current state") are copied like the others. The check reports them as
   "signed by the maintainer" rather than failing, and the README documents them as exceptions with the command that
   verifies them (`--certificate-identity this-is-tobi@proton.me --certificate-oidc-issuer https://github.com/login/oauth`).
   Their signature is no worse at the new path than at the old one.

The copy runs **in a workflow of the repository that owns the chart**, with its `GITHUB_TOKEN` (`packages: write`), so
the package is created by that repository and its release workflow can push to it later. A copy made locally with a
personal token would create packages its workflows cannot push to.

This workflow never lands on `main`. It is added in a pull request that is closed without merging, triggered by
`pull_request`. It runs on the pull request itself, which gets `packages: write` because the branch is in the same
repository. `workflow_dispatch` is not an option: it only runs workflows that are on the default branch.

## Migration steps

Each step lands as one pull request per repository (`gh pr create`, never straight to `main`). helm-charts pins actions
by SHA. rta and homelab keep their `@v0` convention for the shared workflows.

### Step 1: one-chart spike (helm-charts)

Proves the parts nothing in the repositories has shown yet. Run it before anything else.

- A pull request in helm-charts that is never merged adds a `pull_request` workflow. It copies (as in "How a version
  moves") `helm-charts/searxng:0.2.1` (cosign 3 referrers only) and vso-utils 1.1.2 (the oldest version that has a `.sig`
  tag and is signed by `release.yaml`; 1.1.1 is signed by a person) into `charts/`.
- It reports:
  - which repository the new packages are linked to (`gh api users/this-is-tobi/packages/container/charts%2Fsearxng`);
  - the digest at both ends;
  - the verification results.
- Manual: the user makes the two packages public. Then, without credentials: `helm pull` and `cosign verify`.
- **Pass:** both packages linked to helm-charts, same digests, both signatures verify. The copied packages stay; step 2
  completes them.
- **Fail on the link:** the package settings give helm-charts Actions write access, and steps 2 and 3 add that action.
- **Fail on the copy of signatures:** stop and redesign the copy (the fallback is to sign again at the destination, with
  a new identity to document).

### Step 2: helm-charts publishes to `charts/`

Nothing of ours pulls the OCI paths of helm-charts. Outside consumers might (open question): the old paths stay and
are frozen, which stops their updates, so the open question decides how the freeze is announced.

1. A pull request, closed without merging, copies every OCI version of the six charts (51 versions). Then the user makes
   the six packages public.
2. A pull request changes `.github/workflows/release.yaml`: `REPOSITORY: this-is-tobi/charts` on the `release` job
   (`attest` takes its repository from `published-charts`, nothing to change there; the job keeps
   `CREATE_GITHUB_RELEASE: true` until step 6). The same pull request:
   - updates the root README:
     - line 5, the registry;
     - the `helm install` examples (lines 39, 42);
     - the `cosign verify` and `verify-attestation` examples (lines 83, 92);
     - the dependency and Argo CD examples (lines 114, 138);
     - a note that `ghcr.io/this-is-tobi/helm-charts/<chart>` is frozen at the versions it holds;
     - a section "Charts built in other repositories" (rta, ohmlab), kept until step 5;
     - the personal-signature exceptions (see "How a version moves", item 4);
   - updates the README of each of the six charts (`README.md.gotmpl`, then `README.md` through helm-docs), which still
     give the old `oci://` path and `helm repo add tobi`, and are what Artifact Hub displays;
   - bumps the patch version of the four charts that `ct` checks (searxng, homepage, system-upgrade-controller,
     backup-utils): `ct lint` refuses a change under a chart directory without a bump, and a README is part of the
     package. cnpg-cluster and vso-utils are excluded from `ct` and get the same bump, so that all six publish a version
     with the right README. Renovate then proposes the vso-utils, cnpg-cluster, backup-utils, homepage and
     system-upgrade-controller bumps to homelab and template-monorepo-ts, which is step 4 coming early and harmless.
3. **Check:** the merge triggers a release (the change is under `charts/`): the six new versions are in `charts/<chart>`,
   signed, and in the classic Helm repository as before. This is the first release through the new path.

### Step 3: the app repositories publish to `charts/`

The order inside each repository: copy first, then switch the release and the references. Once a consumer points at the
new path, the version it pins must already be there.

**rta**

The chart is renamed `rta` in the same pull request that moves it to `charts/` (see "Chart names"). Nothing was copied with it; the versions of `rta/rta-chart` are copied afterwards (see "Progress").

1. A pull request in rta:
   - `charts/rta-chart/` moves to `charts/rta/` and `Chart.yaml` gets `name: rta`.
   - Everything that names the directory or the chart follows (found with `grep -rn 'rta-chart'`; the builder re-runs it):
     `Makefile:384` (`CHART_DIR`), `internal/app/release_test.go:48`, `.github/ct.yaml`, `.github/workflows/ci.yml:465,493`,
     `.github/workflows/cd.yml:209,229` (`CHART_NAME: rta`), `values.schema.json` (title), the chart's `README.md.gotmpl` and
     `README.md`, `ci/test-values.yaml`, and the `release-please` files if they list the path (to check).
   - `.github/workflows/cd.yml`, `chart` job: `REPOSITORY: this-is-tobi/charts`, and replace the comment above it
     (lines 215-219, which explains why the default is kept).
   - The docs: the install and verify commands become `oci://ghcr.io/this-is-tobi/charts/rta`
     (`docs/10-getting-started/40-other-ways-to-install.md:47`, `docs/90-recipes/10-for-security-teams.md:17`,
     `docs/90-recipes/30-an-agent-in-a-cluster.md:121`, `docs/95-reference/30-verify-a-download.md:42,48`,
     `docs/30-boundary/80-kubernetes.md:30,61,64`), the links to `charts/rta-chart` (`docs/30-boundary/70-oidc.md:147`,
     `docs/30-boundary/80-kubernetes.md:7`), and `kubectl exec deploy/rta-rta-chart-tobi` becomes `deploy/rta-tobi`
     (`docs/90-recipes/30-an-agent-in-a-cluster.md:142`).
   - **The upgrade note**, in the chart README, in `docs/30-boundary/80-kubernetes.md` and in the release notes: "An
     existing release upgrading from `rta/rta-chart` must set `nameOverride: rta-chart`, or its volume is replaced."
     Whether the chart should also refuse to render in that situation (a `lookup` guard in `templates/validation.yaml`; it
     sees nothing under `helm template` or Argo CD) is left to the builder.
2. The French copies of these docs in `this-is-tobi/docs` (`translations/fr/rta/…`, 6 files) follow, by whatever the sync
   from rta does (to check: `docs/.github/workflows/sync.yml`).
3. **Check:**
   - `helm template` of `rta/rta-chart:0.36.0` and of the new chart with `nameOverride: rta-chart` give the same set of
     resource names (a test in the pull request);
   - a fresh install with the release `rta` gives `deploy/rta-tobi`;
   - the first rta release after the merge publishes and signs `charts/rta`.

**homelab**
1. A pull request, closed without merging, copies the 9 versions of `homelab/charts/ohmlab` into `charts/ohmlab`. Then
   the user makes the package public.
2. **First pull request in homelab: allow the new path.** `argo-cd/instances/homelab/values/core/ohmlab.yaml:81`:
   `sourceRepos` gets `ghcr.io/this-is-tobi/charts` next to the old path. The AppProject `sourceRepos` is rendered by the
   ohmlab chart itself, so it has to be synced in Argo CD before anything takes its chart from the new path; a switch in
   the same pull request could block the ohmlab app with its own AppProject.
3. **Second pull request, once the first is synced:**
   - `.github/workflows/cd.yml:228`: `REPOSITORY: this-is-tobi/charts`.
   - `renovate.json:340`: `depNameTemplate` becomes `ghcr.io/this-is-tobi/charts/ohmlab`.
   - `argo-cd/instances/homelab/instance.yaml:20` and `argo-cd/instances/_example/instance.yaml:69`:
     `ohmlab: ghcr.io/this-is-tobi/charts`.
   - `docs/03-installation.md:158,403`.
   - The fixtures in `scripts/ci/test-renovate-managers.sh:64` and `scripts/ci/verify-chart.test.sh:16,103,144`.
4. **Third pull request, later:** the old path leaves `sourceRepos`, once the instance has synced from the new one.
5. **Check:** Argo CD syncs the instance from the new path at the same version, and the next ohmlab release publishes
   there and passes `verify-chart`.

**template-monorepo-ts**
- Nothing to copy, and nothing is released to prove it: the CD only runs on `workflow_dispatch` (its push triggers are
  commented out) and has never released, and dispatching it would cut an app release, images and a chart bump pull
  request. What the pull request changes in `.github/workflows/cd.yml`:
  - the `release-helm` job becomes a `release-helm-local.yml` job (the template is a monorepo; without a `gh-pages`
    branch, `release-helm.yml` at its default `CREATE_GITHUB_RELEASE: true` would run chart-releaser and fail), with
    `REPOSITORY: ${{ github.repository_owner }}/charts` (not hard-coded: a repository made from the template publishes
    into its own account);
  - a new `attest-helm.yml` job like rta's;
  - the comment above the job, which says both channels default to false (`CREATE_GITHUB_RELEASE` defaults to true);
  - `HELM_REPOS` loses `this-is-tobi=` (see step 4).

  **Check:** `actionlint`, and the chart renders with `helm dependency build` and `helm template`. The template's chart
  gets no Artifact Hub entry: it is a template, not a product.

### Step 4: our consumers leave the classic Helm repository

All the pinned versions exist in `charts/` after step 2. The outside consumers are not part of this step (open question).

**homelab**
- Every `Chart.yaml` with `repository: https://this-is-tobi.github.io/helm-charts` (find them with
  `grep -l 'github.io/helm-charts'`; `utils/helm` included) becomes `repository: oci://ghcr.io/this-is-tobi/charts`.
- Regenerate each `Chart.lock` (`helm dependency update`: the lock's digest covers the repository).
- Regenerate `utils/helm/README.md` (helm-docs).
- `.github/workflows/cd.yml:229`: `this-is-tobi=` goes from `HELM_REPOS`.
- Check that `scripts/lib/helm-repos.sh` skips `oci://` repositories. It should already: apisix depends on an OCI chart.

**template-monorepo-ts**
- `helm/Chart.yaml`: both cnpg-cluster dependencies move to `oci://ghcr.io/this-is-tobi/charts`.
- Regenerate `helm/Chart.lock`.
- `cd.yml`: `this-is-tobi=` goes from `HELM_REPOS` (step 3 already does it if both land together).

**Check:** CI renders every chart (`render-example.sh`, `check-vso-isolation.sh`, `test-catalog-bundle.sh`), one app
syncs in Argo CD, and Renovate opens its next vso-utils bump from the new path.

### Step 5: Artifact Hub reads from OCI

The registration data of every chart of the namespace lives in one place, helm-charts, whichever repository builds the
chart. Nothing changes in github-workflows, no chart directory is touched (so no version bump), and the metadata is not
pushed on every release: it is a separate tag (`artifacthub.io`) of the chart's package, and a new chart version does
not remove it.

1. **Artifact Hub** (manual, by the user): one Helm repository per chart, named `this-is-tobi-<chart>`, URL
   `oci://ghcr.io/this-is-tobi/charts/<chart>`. That is 8 repositories (6 + rta + ohmlab). Write down each
   `repositoryID`.
2. **helm-charts**, one pull request:
   - `artifacthub/<chart>.yml` for each of the 8 charts (that chart's `repositoryID`, owners `tobi-or-not` /
     `this-is-tobi@proton.me`);
   - `ci/scripts/push-artifacthub-metadata.sh <chart>`: `oras push ghcr.io/this-is-tobi/charts/<chart>:artifacthub.io
     --config /dev/null:application/vnd.cncf.artifacthub.config.v1+yaml
     artifacthub/<chart>.yml:application/vnd.cncf.artifacthub.repository-metadata.layer.v1.yaml`;
   - the README: how to register a new chart (create the Artifact Hub repository, add the file, run the script).
3. **Run the script once per chart** (the user, with a token that can write the packages).
4. Once the 8 charts show as verified publisher:
   - delete the Artifact Hub repository `this-is-tobi-helm-charts`;
   - point the Artifact Hub links at the new pages (README table, lines 14-19; the `Ref:` comments in
     template-monorepo-ts);
   - drop the README section "Charts built in other repositories" in favour of a link to the Artifact Hub listing.

### Step 6: the classic Helm repository retires (only if the open question allows it)

1. **helm-charts:** `release.yaml` keeps `release-helm.yml` and switches it to OCI-only: `CREATE_GITHUB_RELEASE: false`,
   with `PUBLISH_OCI`, `SKIP_EXISTING`, `REPOSITORY` and `HELM_REPOS` as they are, and without `SIGN_CHART` and
   `SIGNING_KEY_ID`. Then `attest-helm.yml` as today. No change in github-workflows. This removes:
   - chart-releaser, the GitHub Releases and the git tags of the charts, the writes to `gh-pages`, the GPG signature;
   - the secrets `GPG_KEY_ID`, `GPG_PASSPHRASE` and `GPG_PRIVATE_KEY`;
   - the root `artifacthub-repo.yml`;
   - the classic Helm repository sections of the README, replaced by a notice.

   `gh-pages` stays online and frozen, with a notice in its `README.md`.
2. Without chart-releaser no new tag is created, and OCI-only mode takes the latest tag reachable from `HEAD~` as the base
   of its change detection. Each run therefore re-examines every chart changed since the last chart-releaser tag, which
   `SKIP_EXISTING` makes harmless (a published version is left alone). Whether to add a tag step to keep the range short is
   left to the builder.
3. After this step, the only release workflows in use are `release-helm.yml` (OCI-only, helm-charts) and
   `release-helm-local.yml` (the app repositories).

## Order and dependencies

- **Step 1 gates everything.** Its result can change how steps 2 and 3 copy.
- **Steps 2 and 3** are independent once step 1 passes. Step 2 goes first, because its README hosts the index.
- **Step 4** needs step 2 (and step 3 for ohmlab, which is not a dependency anywhere).
- **Step 5** needs steps 2 and 3 (the packages must exist and be public).
- **Step 6** needs step 5 (otherwise Artifact Hub stops seeing new versions), step 4 (otherwise our own consumers lose
  updates), and an answer to the open question.

## Calls made by the author (check them)

- `rta-chart` becomes `rta` (the user's decision), its old versions are copied too (see "Progress"), and existing
  releases add `nameOverride: rta-chart` before 0.43.0 (see "Chart names").
- Only the versions in OCI move. The older ones stay in the frozen classic Helm repository.
- Old OCI packages are frozen, not deleted. Cleaning them is a much later call, once people have migrated (see
  "Progress").
- The copy of the helm-charts and rta versions is a script the owner runs locally; ohmlab's was done the same way
  (see "Progress").
- Versions signed by a person are copied and documented as exceptions, not left out (55 versions in helm-charts stay 55).
- Step 1 is dropped (see "Progress").
- All six helm-charts charts get a patch bump in step 2, to ship READMEs that show the new path (and Renovate proposes
  those bumps downstream early).
- Artifact Hub metadata lives in helm-charts under `artifacthub/<chart>.yml`, is pushed once by a script, and no shared
  workflow pushes it.
- Artifact Hub repositories are named `this-is-tobi-<chart>`.
- The template publishes into `${{ github.repository_owner }}/charts`, moves to `release-helm-local.yml` in step 3,
  gets no Artifact Hub entry, and is not released to test it.
- Step 6 keeps `release-helm.yml` in OCI-only mode for helm-charts, instead of moving it to `release-helm-local.yml`
  (which would need a `SKIP_EXISTING` input and a changed output contract in github-workflows).
- homelab's `sourceRepos` change lands, and syncs, before the switch.

## Open questions (the user's)

- **Does a release of `rta/rta-chart` run anywhere besides your own?** If it is only yours, the upgrade note is enough. If
  others run it, the `lookup` guard and a louder release note are worth building.

- **Who are the outside consumers of the classic Helm repository and of `oci://ghcr.io/this-is-tobi/helm-charts`?**
  IA-Generative (4 repositories) and dnum-mi (2 repositories and a docs repository) pin charts there, and
  `lynh7/home-cluster` copies a README. The owner thinks nobody consumes the OCI charts (2026-11-03): the pins above
  are on the classic Helm repository, which is the question that matters for step 6.
  - If they are yours to migrate, step 4 covers them, the freeze of the old paths costs nothing, and step 6 goes ahead.
  - If they are third parties, step 6 does not happen (chart-releaser, the GitHub Releases and the GPG signature keep
    running, so the classic Helm repository stays alive), and the old OCI paths need either a notice only, or a period
    of publishing to both paths (which costs a second `REPOSITORY` per release in the shared workflows and a second
    attestation).

## Left to the builder

- Whether the `rta` chart refuses to render when it finds the old resources (the `lookup` guard).
- The scripts of the copy workflows, and how they report.
- The script of step 5 and its README section.
- Whether to add a tag step in step 6.
- Splitting a step into several pull requests when review needs it.
