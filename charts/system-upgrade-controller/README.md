# system-upgrade-controller

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: v0.20.2](https://img.shields.io/badge/AppVersion-v0.20.2-informational?style=flat-square)

Secure, plug-and-play Helm chart for the Rancher system-upgrade-controller, with a one-value k3s upgrade preset and generic upgrade Plans.

Kubernetes: `>=1.25.0-0`

## Overview

The [system-upgrade-controller](https://github.com/rancher/system-upgrade-controller) (SUC) upgrades nodes from inside the cluster: each `Plan` selects nodes and runs an upgrade Job on them, a few at a time, cordoning (and optionally draining) each node first. Upstream only publishes raw manifests; this chart packages them with safe defaults.

- **Plug and play**: the defaults deploy the controller, its CRD and RBAC, and upgrade nothing. One value turns on the canonical k3s server + agent Plans.
- **Secured**: upstream's least-privilege RBAC (no `cluster-admin`), and a controller pod that meets the Pod Security `restricted` profile (non-root, read-only root filesystem, no privilege escalation, all capabilities dropped, seccomp, resource requests and limits, no hostPath unless needed).
- **Generic**: any Plan (k3s, RKE2, OS patching, ...) through `plans`; works with Helm 3/4, Argo CD and Flux; can take over an existing upstream-manifest install in place.

## Installing the Chart

**Using Traditional Helm Repository:**
```sh
helm repo add tobi https://this-is-tobi.github.io/helm-charts
helm repo update
helm install system-upgrade tobi/system-upgrade-controller --namespace system-upgrade --create-namespace
```

**Using OCI Registry (Recommended):**
```sh
helm install system-upgrade oci://ghcr.io/this-is-tobi/helm-charts/system-upgrade-controller --version 0.1.0 \
  --namespace system-upgrade --create-namespace
```

The upgrade Jobs are privileged by design (they replace host binaries). If Pod Security Admission is enforced, label the namespace, or let the chart own it with `namespace.create=true`:

```sh
kubectl label namespace system-upgrade pod-security.kubernetes.io/enforce=privileged
```

### CRD

The `plans.upgrade.cattle.io` CRD ships in `crds/`: Helm creates it on the first install and never modifies or deletes it. The controller keeps it current itself, re-registering its embedded CRD (the chart's appVersion) every time it starts. To manage the CRD elsewhere, install with `--skip-crds` (Argo CD: `helm.skipCrds: true`).

If a chart upgrade makes Plans use a field only the new CRD declares and Helm rejects them, re-run the upgrade once the new controller is running, or `kubectl apply` the chart's `crds/` first.

### ArgoCD

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: system-upgrade
spec:
  project: default
  destination:
    server: https://kubernetes.default.svc
    namespace: system-upgrade
  sources:
  - repoURL: ghcr.io/this-is-tobi/helm-charts
    chart: system-upgrade-controller
    targetRevision: 0.1.0
    helm:
      releaseName: system-upgrade
      values: |
        namespace:
          create: true
        k3s:
          enabled: true
          version: v1.36.4+k3s1
```

## Upgrading k3s

```yaml
k3s:
  enabled: true
  version: v1.36.4+k3s1          # or channel: https://update.k3s.io/v1-release/channels/v1.36
  window:                         # optional maintenance window
    days: [monday, tuesday, wednesday, thursday, friday]
    startTime: "02:00"
    endTime: "06:00"
    timeZone: Europe/Paris
```

This renders two Plans:

- `server-plan`: control-plane nodes, one at a time (keeps etcd quorum), cordoned first.
- `agent-plan`: every other node, one at a time; its `prepare` step waits for `server-plan` to finish.

Both accept any Plan field on top of their defaults (`k3s.server.*`, `k3s.agent.*`), e.g. `drain`, `concurrency`, `postCompleteDelay` or `tolerations`.

> [!WARNING]
> Never skip a Kubernetes minor version: go from `v1.35.x` to `v1.36.x`, let both Plans complete, then to `v1.37.x`.

A pinned `version` is deterministic and reviewable (bump it with Renovate or by hand); a `channel` follows new patches on its own every `controller.planPollingInterval`. With a channel the controller needs a CA bundle to reach the channel URL: `caCerts.hostPath: auto` (the default) mounts the host's CA directories only in that case.

## Other Plans

Any Plan goes under `plans`, keyed by name. `planDefaults` is layered under every Plan (k3s preset included). A plan's own fields win; maps deep-merge, lists replace. Every Plan defaults to `concurrency: 1` and the chart's ServiceAccount (the controller treats an unset concurrency as 0 and never runs the Plan).

```yaml
planDefaults:
  window:
    days: [sunday]
    startTime: "01:00"
    endTime: "05:00"
    timeZone: UTC

plans:
  os-patch:
    version: "24.04"                         # bump to run the Plan again
    concurrency: 1
    drain:
      force: true
      ignoreDaemonSets: true
      deleteEmptydirData: true
    nodeSelector:
      matchLabels:
        os-patch: enabled
    upgrade:
      image: docker.io/library/ubuntu      # tagged with `version` by the controller
      command: ["chroot", "/host"]
      args: ["sh", "-c", "apt-get update && apt-get -y upgrade"]
```

A node is marked done with a `plan.upgrade.cattle.io/<plan name>` label holding a hash of the resolved version and the ServiceAccount: renaming a Plan, changing its version or changing `serviceAccount.name` re-runs it on every node. Other fields (`window`, `drain`, `concurrency`, selectors) can change freely.

## Migrating from the upstream manifests

The chart can take over an install made from upstream's `system-upgrade-controller.yaml` without re-running any Plan:

- keep the controller name and Deployment name: `controllerName: system-upgrade-controller`, `fullnameOverride: system-upgrade-controller`;
- keep the ServiceAccount: `serviceAccount.name: system-upgrade`;
- keep your Plan names and versions (`k3s.server.name`, `k3s.agent.name`);
- if the namespace was part of the manifests, keep it managed: `namespace.create: true`.

Argo CD adopts the existing objects in place. Plain Helm refuses objects it does not own: first annotate them with `meta.helm.sh/release-name`, `meta.helm.sh/release-namespace` and label them `app.kubernetes.io/managed-by=Helm`.

## Policy engines

The controller pod passes the Pod Security `restricted` profile and the usual policy-engine rules (non-root, resource limits, no `latest` tag, fully qualified images). The **upgrade Jobs cannot**: they run privileged, as root, with the host's IPC/PID/network namespaces and the host filesystem mounted at `/host`, and the Plan API has no field for their resources. Exempt only them, never the whole namespace. They are named `apply-<plan>-on-<node>-with-<hash>` and labelled `upgrade.cattle.io/controller=<controllerName>`.

Kyverno example (adapt the policy and rule names to yours):

```yaml
apiVersion: kyverno.io/v2
kind: PolicyException
metadata:
  name: system-upgrade-jobs
  namespace: kyverno
spec:
  exceptions:
  - policyName: pod-security-baseline
    ruleNames: [baseline, autogen-baseline]
  match:
    any:
    - resources:
        kinds: [Pod, Job]
        namespaces: [system-upgrade]
        names: [apply-*]
  podSecurity:
  - controlName: Privileged Containers
    images: ["*rancher/k3s-upgrade:*", "*rancher/kubectl:*"]
  - controlName: Host Namespaces
  - controlName: HostPath Volumes
```

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` | Controller affinity. Empty means upstream's: control-plane Linux nodes, one replica per node. |
| caCerts.hostPath | string | `"auto"` | Mount the host CA directories (`/etc/ssl`, `/etc/pki`, `/etc/ca-certificates`) read-only. The controller image ships no CA bundle and only needs one to resolve a Plan `channel` over HTTPS. `auto` mounts them only when a rendered Plan uses a channel, so version-pinned installs keep a restricted-compliant pod (hostPath is not allowed by Pod Security baseline). One of `auto`, `true`, `false`. |
| controller.debug | bool | `false` | Controller debug logging. |
| controller.extraEnv | list | `[]` | Extra controller environment variables. |
| controller.job.activeDeadlineSeconds | int | `900` | Deadline of an upgrade Job, in seconds. |
| controller.job.backoffLimit | int | `99` | Retries of an upgrade Job. |
| controller.job.imagePullPolicy | string | `"Always"` | Pull policy of the upgrade Job images. |
| controller.job.kubectlImage | string | `"docker.io/rancher/kubectl:v1.30.3"` | Image of the cordon/drain containers. Keep it within one minor of the cluster version. |
| controller.job.privileged | bool | `true` | Run upgrade containers privileged (required to replace host binaries). |
| controller.job.ttlSecondsAfterFinish | int | `900` | Seconds before a finished upgrade Job is garbage-collected. |
| controller.leaderElect | bool | `true` | Leader election (required when replicaCount > 1). |
| controller.planPollingInterval | string | `"15m"` | How often Plans are re-resolved (channel polling). |
| controller.threads | int | `2` | Controller worker threads. |
| controllerName | string | `""` | Controller name: the `upgrade.cattle.io/controller` pod label (sole Deployment selector), the leader-election lease and the label put on every upgrade Job. Defaults to the fullname. Must stay unique per cluster and stable across upgrades: in-flight Jobs are tracked by it. |
| extraObjects | list | `[]` | Extra manifests rendered with the release (strings are passed through `tpl`). |
| extraVolumeMounts | list | `[]` | Extra controller volume mounts. |
| extraVolumes | list | `[]` | Extra controller volumes (e.g. a CA bundle ConfigMap instead of `caCerts.hostPath`). |
| fullnameOverride | string | `""` | Override the full resource name (release-name + chart-name). |
| image.digest | string | `""` | Controller image digest (`sha256:...`). Takes precedence over the tag. |
| image.pullPolicy | string | `"IfNotPresent"` | Controller image pull policy. |
| image.registry | string | `"docker.io"` | Controller image registry. |
| image.repository | string | `"rancher/system-upgrade-controller"` | Controller image repository. |
| image.tag | string | `""` | Controller image tag. Defaults to the chart appVersion. |
| imagePullSecrets | list | `[]` | Image pull secrets for the controller pod (upgrade Jobs use `imagePullSecrets` on their Plan). |
| k3s.agent | object | non control-plane nodes, `concurrency: 1`, `cordon: true` | Agent Plan: all other nodes, after the server Plan completes (its `prepare` step waits on it). Accepts `enabled`, `name`, `labels`, `annotations` and any Plan spec field. |
| k3s.channel | string | `""` | k3s release channel URL (e.g. `https://update.k3s.io/v1-release/channels/v1.36`), resolved every `controller.planPollingInterval`. |
| k3s.enabled | bool | `false` | Render the canonical k3s server + agent Plans. |
| k3s.image | string | `"docker.io/rancher/k3s-upgrade"` | Upgrade image, without tag (the controller tags it with the resolved version). |
| k3s.server | object | control-plane nodes, `concurrency: 1`, `cordon: true` | Server Plan: control-plane nodes, one at a time. Accepts `enabled`, `name`, `labels`, `annotations` and any Plan spec field. |
| k3s.version | string | `""` | k3s version to upgrade to (e.g. `v1.36.4+k3s1`). Exactly one of `version` or `channel`. Never skip a minor version. |
| k3s.window | object | `{}` | Maintenance window applied to both Plans (`days`, `startTime`, `endTime`, `timeZone`). |
| nameOverride | string | `""` | Override the chart name (used in resource naming). |
| namespace.annotations | object | `{}` | Namespace annotations. |
| namespace.create | bool | `false` |  |
| namespace.labels | object | `{"pod-security.kubernetes.io/enforce":"privileged"}` | Namespace labels. The upgrade Jobs are privileged by design, so the namespace must allow them. |
| nodeSelector | object | `{}` | Controller node selector. |
| planDefaults | object | `{}` | Defaults layered under every Plan (k3s preset and `plans`): `labels`, `annotations` and any Plan spec field (`window`, `imagePullSecrets`, `priorityClassName`, ...). A plan's own fields win; maps deep-merge, lists replace. |
| plans | object | `{}` | Extra Plans, keyed by name. Each entry accepts `enabled`, `labels`, `annotations` and any Plan spec field (`upgrade` and `version` or `channel` are required; `concurrency` defaults to 1 and `serviceAccountName` to the chart's). |
| podAnnotations | object | `{}` | Controller pod annotations. |
| podLabels | object | `{}` | Controller pod labels. |
| podSecurityContext | object | `{"runAsGroup":65534,"runAsNonRoot":true,"runAsUser":65534,"seccompProfile":{"type":"RuntimeDefault"}}` | Controller pod security context (Pod Security `restricted`). |
| priorityClassName | string | `""` | Controller priority class. |
| rbac.create | bool | `true` | Create the least-privilege Role, ClusterRoles and bindings (upstream's controller + drainer roles). |
| replicaCount | int | `1` | Controller replicas. Leader election makes more than one safe; the anti-affinity spreads them across nodes. |
| resources | object | `{"limits":{"cpu":"250m","memory":"256Mi"},"requests":{"cpu":"10m","memory":"64Mi"}}` | Controller resources. Memory grows with the number of nodes, Plans and Jobs it watches. |
| securityContext | object | `{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":true,"runAsNonRoot":true,"seccompProfile":{"type":"RuntimeDefault"}}` | Controller container security context (Pod Security `restricted`, read-only root filesystem). |
| serviceAccount.annotations | object | `{}` | ServiceAccount annotations. |
| serviceAccount.create | bool | `true` | Create the ServiceAccount used by the controller and, by default, by the upgrade Jobs. |
| serviceAccount.name | string | `""` | ServiceAccount name. Defaults to the fullname. Part of every Plan's hash: changing it re-runs all Plans on every node. |
| strategy | object | `{"type":"Recreate"}` | Deployment strategy (upstream default). |
| tolerations | list | `[{"key":"CriticalAddonsOnly","operator":"Exists"},{"effect":"NoSchedule","key":"node-role.kubernetes.io/master","operator":"Exists"},{"effect":"NoSchedule","key":"node-role.kubernetes.io/controlplane","operator":"Exists"},{"effect":"NoSchedule","key":"node-role.kubernetes.io/control-plane","operator":"Exists"},{"effect":"NoExecute","key":"node-role.kubernetes.io/etcd","operator":"Exists"}]` | Controller tolerations (upstream's control-plane / etcd / CriticalAddonsOnly set). |

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| this-is-tobi | <this-is-tobi@proton.me> | <https://this-is-tobi.com> |

## Sources

**Homepage:** <https://github.com/rancher/system-upgrade-controller>

**Source code:**

* <https://github.com/this-is-tobi/helm-charts>
* <https://github.com/rancher/system-upgrade-controller>

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
