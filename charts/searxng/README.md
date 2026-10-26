# searxng

![Version: 0.2.1](https://img.shields.io/badge/Version-0.2.1-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 2026.9.8-3fdc6d753](https://img.shields.io/badge/AppVersion-2026.9.8--3fdc6d753-informational?style=flat-square)

Secure, plug-and-play Helm chart for SearXNG, the privacy-respecting metasearch engine, with optional Valkey for its limiter.

Kubernetes: `>=1.25.0-0`

## Requirements

Kubernetes: `>=1.25.0-0`

| Repository | Name | Version |
|------------|------|---------|
| oci://registry-1.docker.io/cloudpirates | valkey | 0.25.16 |

## Overview

[SearXNG](https://github.com/searxng/searxng) is a metasearch engine: it queries many search engines and aggregates their results without tracking its users. This chart deploys it with safe defaults.

- **Plug and play**: the defaults run SearXNG with its own default settings and a generated secret key; `settings` only holds what you change.
- **Secured**: the pod meets the Pod Security `restricted` profile (non-root, read-only root filesystem, no privilege escalation, all capabilities dropped, seccomp, resource requests and limits) and gets no ServiceAccount token.
- **OpenShift ready**: on OpenShift, the fixed user and group IDs are left to the SCC.
- **Valkey on demand**: one value adds Valkey for SearXNG's limiter and bot detection.

## Installing the Chart

**Using Traditional Helm Repository:**
```sh
helm repo add tobi https://this-is-tobi.github.io/helm-charts
helm repo update
helm install searxng tobi/searxng --namespace searxng --create-namespace
```

**Using OCI Registry (Recommended):**
```sh
helm install searxng oci://ghcr.io/this-is-tobi/helm-charts/searxng --version 0.2.1 \
  --namespace searxng --create-namespace
```

### ArgoCD

Argo CD renders the chart without cluster access, so the chart cannot keep a generated secret key: give it an existing Secret (see [Secret key](#secret-key)).

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: searxng
spec:
  project: default
  destination:
    server: https://kubernetes.default.svc
    namespace: searxng
  sources:
  - repoURL: ghcr.io/this-is-tobi/helm-charts
    chart: searxng
    targetRevision: 0.2.1
    helm:
      releaseName: searxng
      values: |
        secret:
          existingSecret: searxng-secret
```

## Exposing SearXNG

Through an Ingress or a Gateway API HTTPRoute; set `settings.server.base_url` to the public URL in both cases.

```yaml
ingress:
  enabled: true
  className: nginx
  hosts:
  - name: search.example.com
    paths:
    - path: /
  tls:
  - secretName: search-example-com-tls
    hosts:
    - search.example.com
# or
httpRoute:
  enabled: true
  parentRefs:
  - name: gateway
    namespace: gateway-system
  hostnames:
  - search.example.com
```

## Settings

`settings` is rendered to `/etc/searxng/settings.yml` with `use_default_settings: true`: SearXNG loads its own defaults first and applies yours on top, so only set what differs. See the [settings reference](https://docs.searxng.org/admin/settings/).

```yaml
settings:
  general:
    instance_name: My search
  search:
    # Clients such as Open WebUI query SearXNG for JSON results.
    formats:
    - html
    - json
  server:
    base_url: https://search.example.com/
```

To keep or remove some of SearXNG's default engines, give `use_default_settings` SearXNG's map form (engines you define under `engines` are added to the ones kept):

```yaml
settings:
  use_default_settings:
    engines:
      keep_only:
      - duckduckgo
      - wikipedia
```

Other configuration files (`limiter.toml`, `favicons.toml`, ...) go under `extraConfigFiles`, by file name; they are mounted next to `settings.yml`. The root filesystem is read-only and `/tmp` is the only writable path: keep cache files there (`favicons.toml`'s `db_url` defaults to `/tmp/faviconcache.db`), or mount a volume with `extraVolumes` and `extraVolumeMounts`.

## Secrets in the settings

SearXNG reads only a few settings from its environment (the secret key among them) and cannot include a second file, so a secret value such as the metrics password (`general.open_metrics`) or a proxy's credentials would otherwise sit in `settings`, in git and in the ConfigMap. `settingsFromSecrets` takes it from a Secret key instead, by dotted path:

```yaml
settingsFromSecrets:
- path: general.open_metrics
  name: searxng-metrics
  key: password
```

An init container (the SearXNG image) writes the final `settings.yml`, with the Secret values read from its environment, to an in-memory volume that SearXNG mounts at `/etc/searxng`; `extraConfigFiles` are copied next to it. A path cannot also be set in `settings`, and it addresses keys of nested maps only (not an item of a list such as `engines`). The Secret is read when the pod starts: restart the Deployment after rotating it.

## Secret key

SearXNG signs its sessions and image proxy URLs and encrypts its cache with `server.secret_key`, so every replica needs the same key and it must not change. The chart passes it in the `SEARXNG_SECRET` environment variable, from:

- a Secret the chart creates with a random key, reused on every upgrade (Helm reads it back from the cluster);
- or `secret.existingSecret` (key `secret.key`), required for tools that render without cluster access such as Argo CD, which would otherwise get a new key on every render.

```sh
kubectl -n searxng create secret generic searxng-secret --from-literal=secret-key="$(openssl rand -hex 32)"
```

## Metrics

SearXNG serves Prometheus metrics on `/metrics` when `settings.general.open_metrics` holds a password, checked with HTTP basic auth (any username). SearXNG only reads it from its settings: set it from a Secret with `settingsFromSecrets` (see above), or it ends up in the chart's ConfigMap. `serviceMonitor` scrapes it with the Prometheus Operator, the password coming from the same Secret:

```yaml
settingsFromSecrets:
- path: general.open_metrics
  name: searxng-metrics
  key: password
serviceMonitor:
  enabled: true
  basicAuth:
    username:
      name: searxng-metrics
      key: username
    password:
      name: searxng-metrics
      key: password
```

## Valkey and the limiter

With `valkey.enabled`, the chart deploys [Valkey](https://github.com/CloudPirates-io/helm-charts/tree/main/charts/valkey) (password authentication on, no volume) and points SearXNG at it with `SEARXNG_VALKEY_URL`, built from the Valkey service and the password of its Secret. SearXNG uses it for its bot detection and its [limiter](https://docs.searxng.org/admin/searx.limiter.html), and connects to it once, at startup: a `wait-for-valkey` init container holds SearXNG until Valkey answers.

The subchart generates the password and keeps it across upgrades. Tools that render without cluster access (Argo CD) would generate a new one on every render: give them an existing Secret with `valkey.auth.existingSecret` (key `valkey.auth.existingSecretPasswordKey`), whose password must stay URL-safe.

The limiter stays off until `settings.server.limiter: true`. It then answers `429` to the requests its bot detection does not trust, which includes clients calling SearXNG directly (an Open WebUI web search, for instance): keep it off for those. Behind an ingress, list the ingress controller's addresses in `botdetection.trusted_proxies` (`extraConfigFiles."limiter.toml"`), so that SearXNG takes the client address from `X-Forwarded-For` instead of limiting every user as the ingress.

```yaml
valkey:
  enabled: true
settings:
  server:
    limiter: true
extraConfigFiles:
  limiter.toml: |
    [botdetection]
    # The ingress controller's pod network.
    trusted_proxies = ["10.42.0.0/16"]
```

## OpenShift

OpenShift's restricted SCCs assign the user, group and fsGroup from the namespace's range and reject pods that set others. With `global.compatibility.openshift.adaptSecurityContext: auto` (the default), the chart drops `runAsUser`, `runAsGroup` and `fsGroup` from its security contexts when the cluster serves `security.openshift.io/v1`; `force` drops them anywhere (for platforms that inject IDs the same way), `disabled` keeps them. SearXNG runs with any UID and GID 0: it only writes to its `/tmp` emptyDir. The valkey subchart adapts itself when it detects OpenShift (`route.openshift.io/v1`); with `force` elsewhere, also set `valkey.targetPlatform: openshift`.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` | Affinity. |
| autoscaling.enabled | bool | `false` | Scale SearXNG with a HorizontalPodAutoscaler (needs a metrics server). |
| autoscaling.maxReplicas | int | `3` | Maximum replicas. |
| autoscaling.minReplicas | int | `1` | Minimum replicas. |
| autoscaling.targetCPUUtilizationPercentage | int | `80` | Average CPU utilization target, in percent of the CPU request. |
| autoscaling.targetMemoryUtilizationPercentage | string | `""` | Average memory utilization target, in percent of the memory request. Empty by default: an idle worker already sits near its request. |
| env | list | `[]` | Extra SearXNG environment variables. |
| envFrom | list | `[]` | Extra SearXNG environment variables from ConfigMaps or Secrets. |
| extraConfigFiles | object | `{}` | Extra files rendered next to `settings.yml` in `/etc/searxng`, by file name (e.g. `limiter.toml`, `favicons.toml`). |
| extraObjects | list | `[]` | Extra objects to deploy with the release (rendered with `tpl`). |
| extraVolumeMounts | list | `[]` | Extra volume mounts of the SearXNG container. |
| extraVolumes | list | `[]` | Extra volumes. |
| fullnameOverride | string | `""` | Override the full resource name (release-name + chart-name). |
| global.compatibility.openshift.adaptSecurityContext | string | `"auto"` | Drop `runAsUser`, `runAsGroup` and `fsGroup` from the security contexts so that OpenShift's SCC assigns them from the namespace range (it rejects pods that set others): `auto` when the cluster serves `security.openshift.io/v1`, `force` always, `disabled` never. The valkey subchart adapts itself when it detects OpenShift (`route.openshift.io/v1`); with `force` elsewhere, also set `valkey.targetPlatform: openshift`. |
| httpRoute.annotations | object | `{}` | HTTPRoute annotations. |
| httpRoute.enabled | bool | `false` | Expose SearXNG through a Gateway API HTTPRoute (needs the gateway.networking.k8s.io CRDs). |
| httpRoute.hostnames | list | `[]` | Hostnames the HTTPRoute matches. |
| httpRoute.labels | object | `{}` | HTTPRoute labels. |
| httpRoute.parentRefs | list | `[]` | Gateways (and listeners) the HTTPRoute attaches to. Required. |
| httpRoute.rules | list | `[]` | Routing rules (`matches`, `filters`), all sent to SearXNG. Empty routes everything to it. |
| image.digest | string | `""` | SearXNG image digest (`sha256:...`). Takes precedence over the tag. |
| image.pullPolicy | string | `"IfNotPresent"` | SearXNG image pull policy. |
| image.registry | string | `"docker.io"` | SearXNG image registry. |
| image.repository | string | `"searxng/searxng"` | SearXNG image repository. |
| image.tag | string | `""` | SearXNG image tag. Defaults to the chart appVersion. |
| imagePullSecrets | list | `[]` | Image pull secrets. |
| ingress.annotations | object | `{}` | Ingress annotations. |
| ingress.className | string | `""` | Ingress class. |
| ingress.enabled | bool | `false` | Expose SearXNG through an Ingress. |
| ingress.hosts | list | `[{"name":"searxng.local","paths":[{"path":"/","pathType":"Prefix"}]}]` | Hosts and paths routed to SearXNG. |
| ingress.labels | object | `{}` | Ingress labels. |
| ingress.tls | list | `[]` | Ingress TLS (`secretName` and `hosts`). |
| livenessProbe | object | `{"failureThreshold":3,"httpGet":{"path":"/healthz","port":"http"},"periodSeconds":20,"timeoutSeconds":5}` | Liveness probe. |
| nameOverride | string | `""` | Override the chart name (used in resource naming). |
| nodeSelector | object | `{}` | Node selector. |
| pdb.enabled | bool | `false` | Create a PodDisruptionBudget. |
| pdb.maxUnavailable | int | `1` | Pods that may be unavailable during voluntary disruptions (number or percentage). |
| pdb.minAvailable | string | `""` | Pods that must stay available during voluntary disruptions (number or percentage). Exclusive with `maxUnavailable`: set that one to null to use it. With a single replica, `1` blocks node drains. |
| podAnnotations | object | `{}` | Pod annotations. |
| podLabels | object | `{}` | Pod labels. |
| podSecurityContext | object | `{"fsGroup":977,"runAsGroup":977,"runAsNonRoot":true,"runAsUser":977,"seccompProfile":{"type":"RuntimeDefault"}}` | Pod security context (Pod Security `restricted`). 977 is the image's `searxng` user. |
| priorityClassName | string | `""` | Priority class. |
| readinessProbe | object | `{"httpGet":{"path":"/healthz","port":"http"},"periodSeconds":10,"timeoutSeconds":5}` | Readiness probe. `/healthz` goes through SearXNG's request setup, so a broken configuration fails it, without rendering a page. |
| replicaCount | int | `1` | SearXNG replicas (ignored with `autoscaling.enabled`). They all share the secret key below. |
| resources | object | `{"limits":{"cpu":"1","memory":"512Mi"},"requests":{"cpu":"50m","memory":"160Mi"}}` | Resources. One SearXNG worker uses about 130Mi once warm. |
| secret.existingSecret | string | `""` | Existing Secret holding the SearXNG secret key (`server.secret_key`). When empty, the chart creates one with a random key and keeps it across upgrades. Tools that render without cluster access (Argo CD) would generate a new key on every render: give them an existing Secret. |
| secret.key | string | `"secret-key"` | Key of the secret key in the Secret. |
| securityContext | object | `{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":true}` | Container security context (Pod Security `restricted`, read-only root filesystem: SearXNG only writes to an emptyDir on `/tmp`). |
| service.annotations | object | `{}` | Service annotations. |
| service.port | int | `8080` | Service port. |
| service.type | string | `"ClusterIP"` | Service type. |
| serviceAccount.annotations | object | `{}` | ServiceAccount annotations. |
| serviceAccount.automount | bool | `false` | Mount the ServiceAccount token in the pod. SearXNG never calls the Kubernetes API. |
| serviceAccount.create | bool | `true` | Create the ServiceAccount. |
| serviceAccount.name | string | `""` | ServiceAccount name. Defaults to the fullname, or `default` when not created. |
| serviceMonitor.basicAuth | object | `{}` | Basic auth of the scrape: Secret key references (`name`, `key`) for `username` and `password`, the password matching `settings.general.open_metrics`. Required. |
| serviceMonitor.enabled | bool | `false` | Create a Prometheus Operator ServiceMonitor scraping `/metrics`. SearXNG serves it only when `settings.general.open_metrics` holds a password, checked with HTTP basic auth (any username). |
| serviceMonitor.interval | string | `"30s"` | Scrape interval. |
| serviceMonitor.labels | object | `{}` | ServiceMonitor labels (e.g. the one your Prometheus selects). |
| serviceMonitor.scrapeTimeout | string | `"10s"` | Scrape timeout. |
| settings | object | `{}` | SearXNG settings, rendered to `/etc/searxng/settings.yml` on top of SearXNG's own defaults: set only what you change. The chart sets `use_default_settings: true`; give it SearXNG's map form to keep or remove default engines (e.g. `use_default_settings.engines.keep_only`). The secret key comes from `secret`. See https://docs.searxng.org/admin/settings/. |
| settingsFromSecrets | list | `[]` | Settings whose value comes from a Secret key, by dotted path in `settings` (`path`, Secret `name` and `key`), e.g. `general.open_metrics` or the credentials of `outgoing.proxies`. SearXNG reads only a few settings from its environment and cannot include a second file, so an init container writes the final `settings.yml` into an in-memory volume, with these values read from the container environment. A path cannot also be set in `settings`; a rotated Secret takes a pod restart. |
| startupProbe | object | `{"failureThreshold":24,"httpGet":{"path":"/healthz","port":"http"},"periodSeconds":5}` | Startup probe: gives the first start up to two minutes without delaying the other probes. |
| strategy | object | `{}` | Deployment strategy. |
| tolerations | list | `[]` | Tolerations. |
| topologySpreadConstraints | list | `[]` | Topology spread constraints, e.g. one replica per node: `topologyKey: kubernetes.io/hostname` with a `labelSelector` on `app.kubernetes.io/name: searxng` and the release's `app.kubernetes.io/instance`. |
| valkey.auth.existingSecret | string | `""` | Existing Secret holding the Valkey password (key `auth.existingSecretPasswordKey`). When empty, the subchart creates one with a random password and keeps it across upgrades; tools that render without cluster access (Argo CD) would generate a new one on every render. |
| valkey.enabled | bool | `false` | Deploy Valkey (the [CloudPirates chart](https://github.com/CloudPirates-io/helm-charts/tree/main/charts/valkey)) and point SearXNG at it: `SEARXNG_VALKEY_URL`, with the password of the Valkey Secret, takes precedence over `settings.valkey.url`. SearXNG needs Valkey for its limiter (`settings.server.limiter`) and bot detection, and connects to it once at startup, so an init container waits for it. Any other key configures the subchart. |
| valkey.initContainer.resources | object | `{"limits":{"cpu":"100m","memory":"64Mi"},"requests":{"cpu":"10m","memory":"32Mi"}}` | Resources of the Valkey init container (`architecture: replication`). |
| valkey.metrics.resources | object | `{"limits":{"cpu":"100m","memory":"64Mi"},"requests":{"cpu":"10m","memory":"32Mi"}}` | Resources of the Valkey metrics exporter (`metrics.enabled`). |
| valkey.persistence.enabled | bool | `false` | Persist Valkey's data. It only holds SearXNG's limiter counters and cache. |
| valkey.podSecurityContext | object | `{"fsGroup":1000,"seccompProfile":{"type":"RuntimeDefault"}}` | Valkey pod security context: the subchart's fsGroup plus the seccomp profile Pod Security `restricted` requires. |
| valkey.resources | object | `{"limits":{"cpu":"100m","memory":"128Mi"},"requests":{"cpu":"50m","memory":"64Mi"}}` | Valkey resources (the subchart sets none; quotas and policy engines usually require them). |
| valkey.sentinel.masterProxy.resources | object | `{"limits":{"cpu":"100m","memory":"64Mi"},"requests":{"cpu":"10m","memory":"32Mi"}}` | Resources of the sentinel's HAProxy master proxy (`sentinel.masterProxy.enabled`). |
| valkey.sentinel.resources | object | `{"limits":{"cpu":"100m","memory":"64Mi"},"requests":{"cpu":"10m","memory":"32Mi"}}` | Resources of the Valkey sentinel (`sentinel.enabled`). |

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| this-is-tobi | <this-is-tobi@proton.me> | <https://this-is-tobi.com> |

## Sources

**Homepage:** <https://github.com/searxng/searxng>

**Source code:**

* <https://github.com/this-is-tobi/helm-charts>
* <https://github.com/searxng/searxng>

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
