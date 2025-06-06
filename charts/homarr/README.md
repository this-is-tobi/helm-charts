# homarr

![Version: 0.1.11](https://img.shields.io/badge/Version-0.1.11-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.15.10](https://img.shields.io/badge/AppVersion-0.15.10-informational?style=flat-square)

Customizable browser's home page to interact with your homeserver's Docker containers (e.g. Sonarr/Radarr)

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| https://charts.bitnami.com/bitnami | keycloak | >=24.3.0 |

## Installing the Chart

### CLI

```sh
helm repo add tobi https://this-is-tobi.github.io/helm-charts
helm install <release_name> tobi/homarr
```

### ArgoCD

`application.yaml` :

```yaml
[...]
sources:
- repoURL: https://this-is-tobi.github.io/helm-charts
  chart: homarr
  targetRevision: 0.1.11
  helm:
    releaseName: <release_name>
    parameters: []
    values: ""
```

### Helm dependency

`Chart.yaml`:

```yaml
[...]
dependencies:
- name: homarr
  version: 0.1.11
  repository: https://this-is-tobi.github.io/helm-charts
  condition: homarr.enabled
```

`values.yaml`:

```yaml
[...]
homarr:
  enabled: true
```

## Values

### Global

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| global.env | object | `{}` | Map of environment variables to inject into backend and frontend containers. |
| global.secrets | object | `{}` | Map of environment variables to inject into backend and frontend containers. |

### Image pull secret

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| imageCredentials.email | string | `""` | Email to pull images. |
| imageCredentials.password | string | `""` | Password to pull images. |
| imageCredentials.registry | string | `""` | Registry to pull images from. |
| imageCredentials.username | string | `""` | Username to pull images. |

### Ingress

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| ingress.annotations | object | `{}` | Additional ingress annotations. |
| ingress.className | string | `""` | Defines which ingress controller will implement the resource. |
| ingress.enabled | bool | `true` | Whether or not ingress should be enabled. |
| ingress.hosts | list | `["domain.local"]` | The list of hosts to be covered by ingress record. |
| ingress.labels | object | `{}` | Additional ingress labels. |
| ingress.tls | list | `[]` | Enable TLS configuration. |

### Server

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| server.affinity | object | `{}` | Default affinity for server. |
| server.auth.ldap.ADMIN_GROUP | string | `"admin"` | Admin group. |
| server.auth.ldap.BASE | string | `""` | Base dn of your LDAP server. |
| server.auth.ldap.BIND_DN | string | `""` | User used for finding users and groups. |
| server.auth.ldap.BIND_PASSWORD | string | `""` | Password for bind user. |
| server.auth.ldap.GROUP_CLASS | string | `"groupOfUniqueNames"` | Class used for querying groups. |
| server.auth.ldap.GROUP_FILTER_EXTRA_ARG | string | `""` | Extra arguments for user's groups search filter (& based). |
| server.auth.ldap.GROUP_MEMBER_ATTRIBUTE | string | `"member"` | Attribute used for querying group member. |
| server.auth.ldap.GROUP_MEMBER_USER_ATTRIBUTE | string | `"dn"` | User attribute used for comparing with group member. |
| server.auth.ldap.OWNER_GROUP | string | `"admin"` | Owner group. |
| server.auth.ldap.SEARCH_SCOPE | string | `"base"` | Search scopes between base, one and sub. |
| server.auth.ldap.URI | string | `""` | URI of your LDAP server. |
| server.auth.ldap.USERNAME_ATTRIBUTE | string | `"uid"` | Attribute used for username. |
| server.auth.ldap.USERNAME_FILTER_EXTRA_ARG | string | `""` | Extra arguments for user search filter (& based). |
| server.auth.ldap.USER_MAIL_ATTRIBUTE | string | `"mail"` | Attribute used for mail field. |
| server.auth.logoutRedirectUri | string | `"domain.local"` | URL to redirect to after clicking logging out. |
| server.auth.oidc.ADMIN_GROUP | string | `"admin"` | Admin group. |
| server.auth.oidc.AUTO_LOGIN | bool | `false` | Automatically redirect to OIDC login. |
| server.auth.oidc.CLIENT_ID | string | `""` | ID of OIDC client (application). |
| server.auth.oidc.CLIENT_NAME | string | `"OIDC"` | Display name of provider (in login screen). |
| server.auth.oidc.CLIENT_SECRET | string | `""` | Secret of OIDC client (application). |
| server.auth.oidc.OWNER_GROUP | string | `"admin"` | Owner group. |
| server.auth.oidc.TIMEOUT | int | `3500` | Timeout in milliseconds. |
| server.auth.oidc.URI | string | `""` | URI of OIDC provider. |
| server.auth.provider | string | `"credentials"` | Select Which provider to use between credentials, ldap and oidc. Multiple providers can be enabled with a comma separated list (ex: 'credentials,oidc'), it is highly recommended to just enable one provider. |
| server.auth.sessionExpiryTime | string | `"30d"` | Time for the session to time out. Can be set as pure number, which will automatically be used in seconds, or followed by s, m, h or d for seconds, minutes, hours or days. (ex: "30m"). |
| server.autoscaling.enabled | bool | `false` | Enable Horizontal Pod Autoscaler ([HPA]) for the server. |
| server.autoscaling.maxReplicas | int | `3` | Maximum number of replicas for the server [HPA]. |
| server.autoscaling.minReplicas | int | `1` | Minimum number of replicas for the server [HPA]. |
| server.autoscaling.targetCPUUtilizationPercentage | int | `80` | Average CPU utilization percentage for the server [HPA]. |
| server.autoscaling.targetMemoryUtilizationPercentage | int | `80` | Average memory utilization percentage for the server [HPA]. |
| server.container.args | list | `[]` | server container command args. |
| server.container.command | list | `[]` | server container command. |
| server.container.port | int | `7575` | server container port. |
| server.container.securityContext | object | `{}` | Toggle and define container-level security context. |
| server.env | object | `{}` | server container env variables, it will be injected into a configmap and loaded into the container. |
| server.envFrom | list | `[]` | server container env variables loaded from configmap or secret reference. |
| server.extraContainers | list | `[]` | Extra containers to add to the server pod as sidecars. |
| server.extraVolumeMounts | list | `[]` | List of extra mounts to add (normally used with extraVolumes). |
| server.extraVolumes | list | `[]` | List of extra volumes to add. |
| server.healthcheckPath | string | `"/"` | server container healthcheck endpoint. |
| server.hostAliases | list | `[]` | Host aliases that will be injected at pod-level into /etc/hosts. |
| server.image.pullPolicy | string | `"Always"` | Image pull policy for the server. |
| server.image.repository | string | `"ghcr.io/ajnart/homarr"` | Repository to use for the server. |
| server.image.tag | string | `""` | Tag to use for the server. Overrides the image tag whose default is the chart appVersion. |
| server.initContainers | list | `[]` | Init containers to add to the server pod. |
| server.livenessProbe.enabled | bool | `true` | Whether or not enable the probe. |
| server.livenessProbe.failureThreshold | int | `3` | Minimum consecutive successes for the probe to be considered successful after having failed. |
| server.livenessProbe.initialDelaySeconds | int | `30` | Whether or not enable the probe. |
| server.livenessProbe.periodSeconds | int | `30` | Minimum consecutive failures for the probe to be considered failed after having succeeded. |
| server.livenessProbe.successThreshold | int | `1` | Number of seconds after the container has started before probe is initiated. |
| server.livenessProbe.timeoutSeconds | int | `5` | How often (in seconds) to perform the probe. |
| server.nodeSelector | object | `{}` | Default node selector for server. |
| server.persistence.configs.accessMode | string | `"ReadWriteOnce"` | Access mode for homarr-configs. |
| server.persistence.configs.enabled | bool | `false` | Enable homarr-configs persistent storage. |
| server.persistence.configs.mountPath | string | `"/app/data/configs"` | Mount path inside the pod for homarr-configs. |
| server.persistence.configs.name | string | `"homarr-configs"` | Name for the homarr-configs PersistentVolumeClaim. |
| server.persistence.configs.size | string | `"100Mi"` | Storage size for homarr-configs. |
| server.persistence.configs.storageClassName | string | `""` | Storage class name for homarr-configs. |
| server.persistence.data.accessMode | string | `"ReadWriteOnce"` | Access mode for homarr-data. |
| server.persistence.data.enabled | bool | `false` | Enable homarr-database persistent storage. |
| server.persistence.data.mountPath | string | `"/data"` | Mount path inside the pod for homarr-data. |
| server.persistence.data.name | string | `"homarr-data"` | Name for the homarr-data PersistentVolumeClaim. |
| server.persistence.data.size | string | `"100Mi"` | Storage size for homarr-data. |
| server.persistence.data.storageClassName | string | `""` | Storage class name for homarr-data. |
| server.persistence.icons.accessMode | string | `"ReadWriteOnce"` | Access mode for homarr-icons. |
| server.persistence.icons.enabled | bool | `false` | Enable homarr-icons persistent storage. |
| server.persistence.icons.mountPath | string | `"/app/public/icons"` | Mount path inside the pod for homarr-icons. |
| server.persistence.icons.name | string | `"homarr-icons"` | Name for the homarr-icons PersistentVolumeClaim. |
| server.persistence.icons.size | string | `"100Mi"` | Storage size for homarr-icons. |
| server.persistence.icons.storageClassName | string | `""` | Storage class name for homarr-icons. |
| server.podAnnotations | object | `{}` | Annotations for the server deployed pods. |
| server.podLabels | object | `{}` | Labels for the server deployed pods. |
| server.podSecurityContext | object | `{}` | Toggle and define pod-level security context. |
| server.readinessProbe.enabled | bool | `true` | Whether or not enable the probe. |
| server.readinessProbe.failureThreshold | int | `2` | Minimum consecutive failures for the probe to be considered failed after having succeeded. |
| server.readinessProbe.initialDelaySeconds | int | `15` | Number of seconds after the container has started before probe is initiated. |
| server.readinessProbe.periodSeconds | int | `10` | How often (in seconds) to perform the probe. |
| server.readinessProbe.successThreshold | int | `2` | Minimum consecutive successes for the probe to be considered successful after having failed. |
| server.readinessProbe.timeoutSeconds | int | `5` | Number of seconds after which the probe times out. |
| server.replicaCount | int | `1` | The number of application controller pods to run. |
| server.resources.limits.cpu | string | `"500m"` | CPU limit for the server. |
| server.resources.limits.memory | string | `"2Gi"` | Memory limit for the server. |
| server.resources.requests.cpu | string | `"100m"` | CPU request for the server. |
| server.resources.requests.memory | string | `"256Mi"` | Memory request for the server. |
| server.secrets | object | `{}` | server container env secrets, it will be injected into a secret and loaded into the container. |
| server.service.port | int | `80` | server service port. |
| server.service.type | string | `"ClusterIP"` | server service type. |
| server.serviceAccount.annotations | object | `{}` | Annotations applied to created service account. |
| server.serviceAccount.create | bool | `false` | Create a service account for the API. |
| server.serviceAccount.name | string | `"server-sa"` | Service account name. |
| server.startupProbe.enabled | bool | `true` | Whether or not enable the probe. |
| server.startupProbe.failureThreshold | int | `10` | Minimum consecutive failures for the probe to be considered failed after having succeeded. |
| server.startupProbe.initialDelaySeconds | int | `0` | Number of seconds after the container has started before probe is initiated. |
| server.startupProbe.periodSeconds | int | `10` | How often (in seconds) to perform the probe. |
| server.startupProbe.successThreshold | int | `1` | Minimum consecutive successes for the probe to be considered successful after having failed. |
| server.startupProbe.timeoutSeconds | int | `5` | Number of seconds after which the probe times out. |
| server.strategy.type | string | `"RollingUpdate"` | Strategy type used to replace old Pods by new ones, can be "Recreate" or "RollingUpdate". |
| server.timezone | string | `""` | Any TZ identifier from the wikipedia page (https://en.wikipedia.org/wiki/List_of_tz_database_time_zones). Default to your local timezone. |
| server.tolerations | list | `[]` | Default tolerations for server. |

### Other Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| fullnameOverride | string | `""` | String to fully override the default application name. |
| keycloak.enabled | bool | `false` | Whether or not keycloak should be deployed (See. https://artifacthub.io/packages/helm/bitnami/keycloak?modal=values). |
| nameOverride | string | `""` | Provide a name in place of the default application name. |

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| this-is-tobi | <this-is-tobi@proton.me> | <https://this-is-tobi.com> |

## Sources

**Homepage:** <https://homarr.dev>

**Source code:**

* <https://github.com/this-is-tobi/helm-charts>
* <https://github.com/ajnart/homarr>

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
