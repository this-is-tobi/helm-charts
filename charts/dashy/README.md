# dashy

![Version: 1.0.0](https://img.shields.io/badge/Version-1.0.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 3.1.0](https://img.shields.io/badge/AppVersion-3.1.0-informational?style=flat-square)

A Helm chart to deploy Dashy, a self-hostable personal dashboard that includes status-checking, widgets, themes, icon packs, a UI editor etc...

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| https://charts.bitnami.com/bitnami | keycloak | >=24.3.0 |

## Installing the Chart

### CLI

```sh
helm repo add tobi https://this-is-tobi.github.io/helm-charts
helm install <release_name> tobi/dashy
```

### ArgoCD

`application.yaml` :

```yaml
[...]
sources:
- repoURL: https://this-is-tobi.github.io/helm-charts
  chart: dashy
  targetRevision: 1.0.0
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
- name: dashy
  version: 1.0.0
  repository: https://this-is-tobi.github.io/helm-charts
  condition: dashy.enabled
```

`values.yaml`:

```yaml
[...]
dashy:
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
| server.autoscaling.enabled | bool | `false` | Enable Horizontal Pod Autoscaler ([HPA]) for the server. |
| server.autoscaling.maxReplicas | int | `3` | Maximum number of replicas for the server [HPA]. |
| server.autoscaling.minReplicas | int | `1` | Minimum number of replicas for the server [HPA]. |
| server.autoscaling.targetCPUUtilizationPercentage | int | `80` | Average CPU utilization percentage for the server [HPA]. |
| server.autoscaling.targetMemoryUtilizationPercentage | int | `80` | Average memory utilization percentage for the server [HPA]. |
| server.config | object | `{"pageInfo":{"navLinks":[{"path":"https://github.com/this-is-tobi","title":"GitHub"}],"title":"Home"}}` | Application custom configuration that will be mount inside the container. |
| server.configMountPath | string | `"/app/user-data"` | Mount path for the config file inside the container. |
| server.container.args | list | `[]` | server container command args. |
| server.container.command | list | `[]` | server container command. |
| server.container.port | int | `8080` | server container port. |
| server.container.securityContext | object | `{}` | Toggle and define container-level security context. |
| server.env | object | `{}` | server container env variables, it will be injected into a configmap and loaded into the container. |
| server.envFrom | list | `[]` | server container env variables loaded from configmap or secret reference. |
| server.extraContainers | list | `[]` | Extra containers to add to the server pod as sidecars. |
| server.extraVolumeMounts | list | `[]` | List of extra mounts to add (normally used with extraVolumes). |
| server.extraVolumes | list | `[]` | List of extra volumes to add. |
| server.healthcheckPath | string | `"/"` | server container healthcheck endpoint. |
| server.hostAliases | list | `[]` | Host aliases that will be injected at pod-level into /etc/hosts. |
| server.image.pullPolicy | string | `"Always"` | Image pull policy for the server. |
| server.image.repository | string | `"docker.io/lissy93/dashy"` | Repository to use for the server. |
| server.image.tag | string | `""` | Tag to use for the server. Overrides the image tag whose default is the chart appVersion. |
| server.initContainers | list | `[]` | Init containers to add to the server pod. |
| server.livenessProbe.enabled | bool | `true` | Whether or not enable the probe. |
| server.livenessProbe.failureThreshold | int | `3` | Minimum consecutive successes for the probe to be considered successful after having failed. |
| server.livenessProbe.initialDelaySeconds | int | `30` | Whether or not enable the probe. |
| server.livenessProbe.periodSeconds | int | `30` | Minimum consecutive failures for the probe to be considered failed after having succeeded. |
| server.livenessProbe.successThreshold | int | `1` | Number of seconds after the container has started before probe is initiated. |
| server.livenessProbe.timeoutSeconds | int | `5` | How often (in seconds) to perform the probe. |
| server.nodeSelector | object | `{}` | Default node selector for server. |
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

**Homepage:** <https://dashy.to>

**Source code:**

* <https://github.com/this-is-tobi/helm-charts>
* <https://github.com/Lissy93/dashy>

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
