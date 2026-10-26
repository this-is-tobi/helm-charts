# homepage

![Version: 0.2.0](https://img.shields.io/badge/Version-0.2.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: v2.7.0](https://img.shields.io/badge/AppVersion-v2.7.0-informational?style=flat-square)

Secure, plug-and-play Helm chart for Homepage, the customizable application dashboard, with optional Kubernetes service discovery and built-in authentication.

Kubernetes: `>=1.25.0-0`

## Overview

[Homepage](https://github.com/gethomepage/homepage) is a dashboard for your services, bookmarks and widgets, configured with YAML files. This chart deploys it with safe defaults.

- **Plug and play**: the defaults run an empty dashboard; `config` holds your files, and the hosts of the `ingress` and `httpRoute` the chart creates are allowed automatically.
- **Secured**: the pod meets the Pod Security `restricted` profile (non-root, read-only root filesystem, no privilege escalation, all capabilities dropped, seccomp, resource requests and limits) and gets no ServiceAccount token.
- **Cluster access on demand**: one value adds Kubernetes service discovery, with a read-only ClusterRole limited to what the enabled features read.
- **Authentication on demand**: Homepage's built-in password or OIDC login, with its secrets kept in a Secret.
- **OpenShift ready**: on OpenShift, the fixed user and group IDs are left to the SCC.

> [!NOTE]
> This chart is a port of the [UnknownIQ homepage chart](https://artifacthub.io/packages/helm/unknowniq/homepage), with its own values: `ingress.main` is `ingress` (hosts are `name`), `route` is `httpRoute`, and the `config` blocks keep their names. It drops the ServiceMonitor (Homepage serves no metrics) and the config PersistentVolumeClaim (the configuration comes from the values, and a copy kept on a volume would ignore later changes to them). The NetworkPolicy stays, opt-in and reworked.

## Installing the Chart

**Using Traditional Helm Repository:**
```sh
helm repo add tobi https://this-is-tobi.github.io/helm-charts
helm repo update
helm install homepage tobi/homepage --namespace homepage --create-namespace
```

**Using OCI Registry (Recommended):**
```sh
helm install homepage oci://ghcr.io/this-is-tobi/helm-charts/homepage --version 0.2.0 \
  --namespace homepage --create-namespace
```

### ArgoCD

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: homepage
spec:
  project: default
  destination:
    server: https://kubernetes.default.svc
    namespace: homepage
  sources:
  - repoURL: ghcr.io/this-is-tobi/helm-charts
    chart: homepage
    targetRevision: 0.2.0
    helm:
      releaseName: homepage
      values: |
        ingress:
          enabled: true
          hosts:
          - name: home.example.com
            paths:
            - path: /
```

Argo CD renders the chart without cluster access: with `auth.enabled`, give it an existing Secret (see [Authentication](#authentication)).

## Exposing Homepage

Through an Ingress or a Gateway API HTTPRoute.

```yaml
ingress:
  enabled: true
  className: nginx
  hosts:
  - name: home.example.com
    paths:
    - path: /
  tls:
  - secretName: home-example-com-tls
    hosts:
    - home.example.com
# or
httpRoute:
  enabled: true
  parentRefs:
  - name: gateway
    namespace: gateway-system
  hostnames:
  - home.example.com
```

### Allowed hosts

Homepage answers `400 Host validation failed` to any `Host` header it was not told about (`HOMEPAGE_ALLOWED_HOSTS`; `localhost:3000` is always allowed). The chart allows, on its own:

- the hosts of `ingress.hosts` (when enabled),
- the `httpRoute.hostnames` (when enabled; wildcard ones are skipped, Homepage compares hosts as they are),
- the host of `auth.externalUrl`.

For a route the chart does not create (an ApisixRoute, a Traefik IngressRoute, a Gateway managed elsewhere, ...), add its host with `allowedHosts`, with its port when it is not the default one. `"*"` allows any host. To take over completely, set `HOMEPAGE_ALLOWED_HOSTS` in `env`: the chart then sets nothing.

```yaml
allowedHosts:
- home.example.com
- home.example.com:8443
```

The probes send `Host: localhost:3000` for the same reason, so they never depend on the list.

## Configuration

`config` holds one value per file of Homepage's config directory ([reference](https://gethomepage.dev/configs/)), rendered into a ConfigMap and mounted read-only. Homepage exits when a file is missing and its directory is read-only, so the chart always renders all nine, empty ones included.

```yaml
config:
  settings:
    title: Home
    theme: dark
    layout:
      Media:
        style: row
        columns: 3
  services:
  - Media:
    - Jellyfin:
        href: https://jellyfin.example.com
        description: Movies and shows
  bookmarks:
  - Developer:
    - GitHub:
      - abbr: GH
        href: https://github.com
  widgets:
  - search:
      provider: duckduckgo
      target: _blank
customCss: |
  body { background: #101418; }
```

The pod rolls when the configuration changes. The root filesystem is read-only: Homepage only writes to emptyDirs on `/app/config/logs` and `/app/.next/cache`. It logs to stdout (`LOG_TARGETS`, overridable in `env`); mount a volume with `extraVolumes` and `extraVolumeMounts` for anything else.

### Local images and icons

Backgrounds and icons referenced as `/images/...` and `/icons/...` are read from `/app/public/images` and `/app/public/icons`. Mount a volume on them with `extraVolumes` and `extraVolumeMounts` (a PersistentVolumeClaim you fill, or a ConfigMap for a few small files); Homepage lists the icons when it starts, so restart it after adding some.

```yaml
config:
  settings:
    background: /images/background.png
extraVolumes:
- name: images
  persistentVolumeClaim:
    claimName: homepage-images
extraVolumeMounts:
- name: images
  mountPath: /app/public/images
  readOnly: true
```

### Secrets in the configuration

Widgets need API keys, which should not sit in `config`, in git and in the ConfigMap. Homepage replaces `{{HOMEPAGE_VAR_NAME}}` in its files with the environment variable `HOMEPAGE_VAR_NAME`, so take the value from a Secret key with `env`:

```yaml
config:
  widgets:
  - openmeteo:
      label: Home
      latitude: 48.85
      longitude: 2.35
  services:
  - Media:
    - Jellyfin:
        href: https://jellyfin.example.com
        widget:
          type: jellyfin
          url: https://jellyfin.example.com
          key: "{{HOMEPAGE_VAR_JELLYFIN_KEY}}"
env:
- name: HOMEPAGE_VAR_JELLYFIN_KEY
  valueFrom:
    secretKeyRef:
      name: homepage-secrets
      key: jellyfin-key
```

`envFrom` takes a whole Secret at once; `HOMEPAGE_FILE_NAME` variables read the value from a file instead (mount the Secret with `extraVolumes`). The Secret is read when the pod starts: restart the Deployment after rotating it.

## Authentication

Homepage has no authentication unless you turn on its own (v2+), so it serves its pages and its widget APIs to whoever reaches it: keep it behind a network or a proxy that authenticates, or set `auth.enabled`. `auth.externalUrl` is required (Homepage builds its sign-in redirects from it; use `https` unless it is a trusted LAN).

```yaml
auth:
  enabled: true
  externalUrl: https://home.example.com
```

The chart then creates a Secret with a random auth secret (`HOMEPAGE_AUTH_SECRET`, which signs the sessions) and a random password (`HOMEPAGE_AUTH_PASSWORD`), kept across upgrades, so every replica shares them and nobody is signed out:

```sh
kubectl -n homepage get secret homepage-homepage-auth -o jsonpath='{.data.password}' | base64 -d
```

Tools that render without cluster access (Argo CD) would generate new ones on every render: give them an existing Secret (keys `auth-secret` and `password`, renameable with `auth.secret.*Key`).

```sh
kubectl -n homepage create secret generic homepage-auth \
  --from-literal=auth-secret="$(openssl rand -base64 32)" --from-literal=password="$(openssl rand -base64 24)"
```

```yaml
auth:
  enabled: true
  externalUrl: https://home.example.com
  secret:
    existingSecret: homepage-auth
```

For OIDC, the provider's callback URI is `<externalUrl>/api/auth/callback/homepage-oidc`, and the Secret (which the chart cannot generate) also holds the client secret (key `oidc-client-secret`). Homepage lets in everyone the provider authorizes for the client: restrict it there.

```yaml
auth:
  enabled: true
  externalUrl: https://home.example.com
  secret:
    existingSecret: homepage-auth
  oidc:
    enabled: true
    issuer: https://auth.example.com/realms/home
    clientId: homepage
```

`/api/healthcheck` stays public, so the probes keep working. Homepage does not limit password attempts: do it on your ingress, for `POST /api/auth/callback/credentials`.

## Kubernetes integration

Off by default: a dashboard needs no access to the cluster. `kubernetes.enabled` mounts the ServiceAccount token, sets Homepage's Kubernetes `mode` to `cluster`, and creates a ClusterRole and binding (`kubernetes.rbac.create`) for what Homepage reads:

| Feature | Read |
| --- | --- |
| Kubernetes widget, pod status of services | nodes, pods, namespaces and their metrics (needs a metrics server) |
| Discovery from `gethomepage.dev/*` annotations | ingresses |
| `config.kubernetes.traefik: true` | Traefik IngressRoutes, and the CRDs Homepage checks for |
| `config.kubernetes.gateway: true` | Gateway API HTTPRoutes and their Gateways |

```yaml
kubernetes:
  enabled: true
config:
  kubernetes:
    ingress: true
    gateway: true
  widgets:
  - kubernetes:
      cluster:
        show: true
        cpu: true
        memory: true
      nodes:
        show: true
        cpu: true
        memory: true
```

Annotate an Ingress (or HTTPRoute) with `gethomepage.dev/enabled: "true"`, `gethomepage.dev/name`, `gethomepage.dev/group`, ... to list it ([reference](https://gethomepage.dev/configs/kubernetes/)). Bring your own RBAC with `kubernetes.rbac.create: false`, or add rules with `kubernetes.rbac.extraRules`. `config.kubernetes.mode` overrides the mode (`default` reads a kubeconfig you mount with `extraVolumes`).

## Network policy

Off by default: Homepage queries whatever your widgets point at, so a policy has to know them. With `networkPolicy.enabled` (on a CNI that enforces policies), Homepage can only be reached on its port and can only reach DNS (ports 53 and 5353), the Kubernetes API (with `kubernetes.enabled`) and what you list. Widgets and an OIDC provider will fail until you do:

```yaml
networkPolicy:
  enabled: true
  ingress:
    # Only the ingress controller reaches Homepage (empty: any source).
    from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: ingress-nginx
  egress:
    rules:
    # Widgets on the LAN, and the OIDC provider.
    - to:
      - ipBlock:
          cidr: 192.168.0.0/16
    - to:
      - ipBlock:
          cidr: 0.0.0.0/0
          except: [10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 169.254.0.0/16]
      ports:
      - protocol: TCP
        port: 443
```

Restricting only the ingress is `egress.rules: [{}]`, which allows every destination.

## Overriding the defaults

Everything the chart sets can be changed, extended or turned off:

| To | Do |
| --- | --- |
| Loosen the pod hardening | Set the key to change (`securityContext.readOnlyRootFilesystem: false`). Maps merge with the defaults, so `null` removes a key (`securityContext.capabilities: null`) |
| Drop a probe | Set it to `null` (`startupProbe: null`): `{}` keeps the default |
| Log to a file as well | `LOG_TARGETS=both` in `env`: the logs emptyDir is already mounted |
| Take over the allowed hosts | `HOMEPAGE_ALLOWED_HOSTS` in `env` |
| Bring your own RBAC or ServiceAccount | `kubernetes.rbac.create: false`, `serviceAccount.create: false` and `serviceAccount.name` |
| Keep more or fewer old ReplicaSets | `revisionHistoryLimit` |
| Annotate the Deployment (Reloader, Argo CD) | `deploymentAnnotations` |
| Add anything else | `extraObjects` (rendered with `tpl`), `extraVolumes`, `extraVolumeMounts`, `env`, `envFrom` |

## Multiple replicas

Replicas share nothing but the configuration (and, with `auth.enabled`, the auth secret). Homepage re-renders pages needlessly when requests alternate between replicas: enable sticky sessions on your ingress or route when you run more than one, for instance with `autoscaling.enabled`.

## OpenShift

OpenShift's restricted SCCs assign the user, group and fsGroup from the namespace's range and reject pods that set others. With `global.compatibility.openshift.adaptSecurityContext: auto` (the default), the chart drops `runAsUser`, `runAsGroup` and `fsGroup` from its security contexts when the cluster serves `security.openshift.io/v1`; `force` drops them anywhere (for platforms that inject IDs the same way), `disabled` keeps them. Homepage runs with any UID and GID 0: it only writes to its emptyDirs.

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` | Affinity. |
| allowedHosts | list | `[]` | Extra hosts Homepage accepts in the `Host` header (`HOMEPAGE_ALLOWED_HOSTS`), on top of those the chart derives from `ingress.hosts`, `httpRoute.hostnames` and the host of `auth.externalUrl`. List a host here when the route is not created by this chart (an ApisixRoute, a Traefik IngressRoute, ...), with its port when it is not the default one. `"*"` allows any host and replaces the rest. Setting `HOMEPAGE_ALLOWED_HOSTS` in `env` replaces the whole list. |
| auth.enabled | bool | `false` | Enable Homepage's built-in authentication (v2+): a password, or OIDC with `auth.oidc.enabled`. Without it, Homepage serves its pages and APIs to whoever reaches it: keep it behind a network or a proxy that authenticates. Homepage does not rate limit password attempts: do it at the ingress (`POST /api/auth/callback/credentials`). |
| auth.externalUrl | string | `""` | Public URL Homepage is reached at (`HOMEPAGE_EXTERNAL_URL`), such as `https://home.example.com`. Required with `auth.enabled`; use `https` for anything but a trusted LAN. |
| auth.oidc.autoLogin | bool | `false` | Send visitors straight to the provider (`HOMEPAGE_OIDC_AUTO_LOGIN`). `/auth/signin?autologin=0` still shows the login page. |
| auth.oidc.clientId | string | `""` | OIDC client ID (`HOMEPAGE_OIDC_CLIENT_ID`). |
| auth.oidc.enabled | bool | `false` | Log in through an OpenID Connect provider instead of a password. The provider's callback URI is `<externalUrl>/api/auth/callback/homepage-oidc`. Homepage lets in everyone the provider authorizes for the client: restrict it there. |
| auth.oidc.issuer | string | `""` | OIDC issuer URL (`HOMEPAGE_OIDC_ISSUER`). |
| auth.oidc.name | string | `""` | Name of the provider on the login button (`HOMEPAGE_OIDC_NAME`). |
| auth.oidc.scope | string | `""` | Scopes to request (`HOMEPAGE_OIDC_SCOPE`). Homepage defaults to `openid email profile`. |
| auth.secret.authSecretKey | string | `"auth-secret"` | Key of the auth secret (`HOMEPAGE_AUTH_SECRET`, at least 32 characters). |
| auth.secret.existingSecret | string | `""` | Existing Secret holding the auth secret, the password (password login) and the OIDC client secret (OIDC), under the keys below. When empty, the chart creates one with a random auth secret and a random password, and keeps them across upgrades; OIDC always needs an existing Secret. Tools that render without cluster access (Argo CD) would generate new ones on every render: give them an existing Secret. |
| auth.secret.oidcClientSecretKey | string | `"oidc-client-secret"` | Key of the OIDC client secret (`HOMEPAGE_OIDC_CLIENT_SECRET`). |
| auth.secret.passwordKey | string | `"password"` | Key of the password (`HOMEPAGE_AUTH_PASSWORD`). |
| autoscaling.enabled | bool | `false` | Scale Homepage with a HorizontalPodAutoscaler (needs a metrics server). |
| autoscaling.maxReplicas | int | `3` | Maximum replicas. |
| autoscaling.minReplicas | int | `1` | Minimum replicas. |
| autoscaling.targetCPUUtilizationPercentage | int | `80` | Average CPU utilization target, in percent of the CPU request. |
| autoscaling.targetMemoryUtilizationPercentage | string | `""` | Average memory utilization target, in percent of the memory request. Empty by default: a warm pod already sits near its request. |
| config.bookmarks | list | `[]` | `bookmarks.yaml`: bookmark groups. List. |
| config.docker | object | `{}` | `docker.yaml`: Docker instances, reached over TCP (a mounted socket would need a hostPath, which Pod Security `restricted` forbids). Map. |
| config.kubernetes | object | `{}` | `kubernetes.yaml`: discovery options (`ingress`, `traefik`, `gateway`) and `mode`. The mode is `cluster` with `kubernetes.enabled` and `disabled` otherwise; set it for `default` (a kubeconfig you mount with `extraVolumes`). Map. |
| config.proxmox | object | `{}` | `proxmox.yaml`: Proxmox instances. Map. |
| config.services | list | `[]` | `services.yaml`: service groups. List. |
| config.settings | object | `{}` | `settings.yaml`: title, theme, layout, providers. Map. |
| config.widgets | list | `[]` | `widgets.yaml`: information widgets. List. |
| customCss | string | `""` | `custom.css`, loaded by every page. |
| customJs | string | `""` | `custom.js`, loaded by every page. |
| deploymentAnnotations | object | `{}` | Deployment annotations, for what reads them on the Deployment itself (Reloader, Argo CD hooks, ...). |
| env | list | `[]` | Extra Homepage environment variables. `HOMEPAGE_VAR_*` ones fill `{{HOMEPAGE_VAR_NAME}}` placeholders in the config; `LOG_TARGETS` (`stdout` by default here) and `HOMEPAGE_ALLOWED_HOSTS` replace the chart's own. |
| envFrom | list | `[]` | Extra Homepage environment variables from ConfigMaps or Secrets. |
| extraObjects | list | `[]` | Extra objects to deploy with the release (rendered with `tpl`). |
| extraVolumeMounts | list | `[]` | Extra volume mounts of the Homepage container. |
| extraVolumes | list | `[]` | Extra volumes. |
| fullnameOverride | string | `""` | Override the full resource name (release-name + chart-name). |
| global.compatibility.openshift.adaptSecurityContext | string | `"auto"` | Drop `runAsUser`, `runAsGroup` and `fsGroup` from the security contexts so that OpenShift's SCC assigns them from the namespace range (it rejects pods that set others): `auto` when the cluster serves `security.openshift.io/v1`, `force` always, `disabled` never. |
| httpRoute.annotations | object | `{}` | HTTPRoute annotations. |
| httpRoute.enabled | bool | `false` | Expose Homepage through a Gateway API HTTPRoute (needs the gateway.networking.k8s.io CRDs). |
| httpRoute.hostnames | list | `[]` | Hostnames the HTTPRoute matches. They are allowed in the `Host` header automatically. |
| httpRoute.labels | object | `{}` | HTTPRoute labels. |
| httpRoute.parentRefs | list | `[]` | Gateways (and listeners) the HTTPRoute attaches to. Required. |
| httpRoute.rules | list | `[]` | Routing rules (`matches`, `filters`), all sent to Homepage. Empty routes everything to it. |
| image.digest | string | `""` | Homepage image digest (`sha256:...`). Takes precedence over the tag. |
| image.pullPolicy | string | `"IfNotPresent"` | Homepage image pull policy. |
| image.registry | string | `"ghcr.io"` | Homepage image registry. |
| image.repository | string | `"gethomepage/homepage"` | Homepage image repository. |
| image.tag | string | `""` | Homepage image tag. Defaults to the chart appVersion. |
| imagePullSecrets | list | `[]` | Image pull secrets. |
| ingress.annotations | object | `{}` | Ingress annotations. |
| ingress.className | string | `""` | Ingress class. |
| ingress.enabled | bool | `false` | Expose Homepage through an Ingress. |
| ingress.hosts | list | `[{"name":"homepage.local","paths":[{"path":"/","pathType":"Prefix"}]}]` | Hosts and paths routed to Homepage. They are allowed in the `Host` header automatically. |
| ingress.labels | object | `{}` | Ingress labels. |
| ingress.tls | list | `[]` | Ingress TLS (`secretName` and `hosts`). |
| kubernetes.enabled | bool | `false` | Let Homepage query the cluster, for its Kubernetes widget, pod status and service discovery from `gethomepage.dev/*` annotations (`config.kubernetes`). It mounts the ServiceAccount token in the pod and, with `kubernetes.rbac.create`, gets a read-only ClusterRole. Off by default: a dashboard with no integration needs no access to the cluster. |
| kubernetes.rbac.create | bool | `true` | Create the ClusterRole and ClusterRoleBinding, limited to what Homepage reads: nodes, pods and their metrics, ingresses, and, when `config.kubernetes.traefik` or `config.kubernetes.gateway` are set, Traefik IngressRoutes or Gateway API routes. Set to false to bring your own. |
| kubernetes.rbac.extraRules | list | `[]` | Extra rules for the ClusterRole. |
| livenessProbe | object | `{"failureThreshold":3,"httpGet":{"httpHeaders":[{"name":"Host","value":"localhost:3000"}],"path":"/api/healthcheck","port":"http"},"periodSeconds":20,"timeoutSeconds":5}` | Liveness probe. |
| nameOverride | string | `""` | Override the chart name (used in resource naming). |
| networkPolicy.egress.rules | list | `[]` | Extra egress rules (NetworkPolicy `egress` items: `to` and `ports`), e.g. the services your widgets query. `[{}]` allows all egress. |
| networkPolicy.enabled | bool | `false` | Create a NetworkPolicy (it only counts on a CNI that enforces them). Once on, Homepage can only be reached on its port and can only reach DNS, the Kubernetes API (with `kubernetes.enabled`) and what `egress.rules` lists: add your widgets' and OIDC provider's destinations there, or `[{}]` to allow all egress. |
| networkPolicy.ingress.from | list | `[]` | Peers allowed to reach Homepage (NetworkPolicy `from` items: `podSelector`, `namespaceSelector`, `ipBlock`), e.g. your ingress controller's namespace. Empty allows any source. |
| nodeSelector | object | `{}` | Node selector. |
| pdb.enabled | bool | `false` | Create a PodDisruptionBudget. |
| pdb.maxUnavailable | int | `1` | Pods that may be unavailable during voluntary disruptions (number or percentage). |
| pdb.minAvailable | string | `""` | Pods that must stay available during voluntary disruptions (number or percentage). Exclusive with `maxUnavailable`: set that one to null to use it. With a single replica, `1` blocks node drains. |
| podAnnotations | object | `{}` | Pod annotations. |
| podLabels | object | `{}` | Pod labels. |
| podSecurityContext | object | `{"fsGroup":1000,"runAsGroup":1000,"runAsNonRoot":true,"runAsUser":1000,"seccompProfile":{"type":"RuntimeDefault"}}` | Pod security context (Pod Security `restricted`). 1000 is the user and group the image's files belong to. |
| priorityClassName | string | `""` | Priority class. |
| readinessProbe | object | `{"httpGet":{"httpHeaders":[{"name":"Host","value":"localhost:3000"}],"path":"/api/healthcheck","port":"http"},"periodSeconds":10,"timeoutSeconds":5}` | Readiness probe. |
| replicaCount | int | `1` | Homepage replicas (ignored with `autoscaling.enabled`). With more than one, enable sticky sessions on your ingress to avoid needless page re-renders; with `auth.enabled` they all share the same auth secret. |
| resources | object | `{"limits":{"cpu":"1","memory":"512Mi"},"requests":{"cpu":"50m","memory":"192Mi"}}` | Resources. Homepage uses about 130Mi once warm; widgets and service lookups add to it. |
| revisionHistoryLimit | int | `3` | Old ReplicaSets kept for rollbacks. A configuration change rolls the pod, so Kubernetes' default of 10 piles up. |
| securityContext | object | `{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]},"readOnlyRootFilesystem":true}` | Container security context (Pod Security `restricted`, read-only root filesystem: Homepage only writes to emptyDirs on its cache and log directories). |
| service.annotations | object | `{}` | Service annotations. |
| service.port | int | `3000` | Service port. |
| service.type | string | `"ClusterIP"` | Service type. |
| serviceAccount.annotations | object | `{}` | ServiceAccount annotations. |
| serviceAccount.create | bool | `true` | Create the ServiceAccount. Its token is mounted in the pod only with `kubernetes.enabled`. |
| serviceAccount.name | string | `""` | ServiceAccount name. Defaults to the fullname, or `default` when not created. |
| startupProbe | object | `{"failureThreshold":24,"httpGet":{"httpHeaders":[{"name":"Host","value":"localhost:3000"}],"path":"/api/healthcheck","port":"http"},"periodSeconds":5}` | Startup probe. `/api/healthcheck` stays public with `auth.enabled`; Homepage rejects any `Host` it was not told about, so the probes send the one it always accepts. |
| strategy | object | `{}` | Deployment strategy. |
| tolerations | list | `[]` | Tolerations. |
| topologySpreadConstraints | list | `[]` | Topology spread constraints, e.g. one replica per node: `topologyKey: kubernetes.io/hostname` with a `labelSelector` on `app.kubernetes.io/name: homepage` and the release's `app.kubernetes.io/instance`. |

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| this-is-tobi | <this-is-tobi@proton.me> | <https://this-is-tobi.com> |

## Sources

**Homepage:** <https://github.com/gethomepage/homepage>

**Source code:**

* <https://github.com/this-is-tobi/helm-charts>
* <https://github.com/gethomepage/homepage>

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
