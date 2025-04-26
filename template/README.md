# app-name

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.1.0](https://img.shields.io/badge/AppVersion-0.1.0-informational?style=flat-square)
A Helm chart to deploy ...

## Installing the Chart

### CLI

```sh
helm repo add tobi https://this-is-tobi.github.io/helm-charts
helm install <release_name> tobi/app-name
```

### ArgoCD

`application.yaml` :

```yaml
[...]
sources:
- repoURL: https://this-is-tobi.github.io/helm-charts
  chart: app-name
  targetRevision: 0.1.0
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
- name: app-name
  version: 0.1.0
  repository: https://this-is-tobi.github.io/helm-charts
  condition: app-name.enabled
```

`values.yaml`:

```yaml
[...]
cnpg-cluster:
  enabled: true
```

## Values

### App

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| app.affinity | object | `{}` | Default affinity for app. |
| app.autoscaling.enabled | bool | `false` | Enable Horizontal Pod Autoscaler ([HPA]) for the app. |
| app.autoscaling.maxReplicas | int | `3` | Maximum number of replicas for the app [HPA]. |
| app.autoscaling.minReplicas | int | `1` | Minimum number of replicas for the app [HPA]. |
| app.autoscaling.targetCPUUtilizationPercentage | int | `80` | Average CPU utilization percentage for the app [HPA]. |
| app.autoscaling.targetMemoryUtilizationPercentage | int | `80` | Average memory utilization percentage for the app [HPA]. |
| app.container.args | list | `[]` | app container command args. |
| app.container.command | list | `[]` | app container command. |
| app.container.port | int | `8080` | app container port. |
| app.container.securityContext | object | `{}` | Toggle and define container-level security context. |
| app.env | object | `{}` | app container env variables, it will be injected into a configmap and loaded into the container. |
| app.envFrom | list | `[]` | app container env variables loaded from configmap or secret reference. |
| app.extraContainers | list | `[]` | Extra containers to add to the app pod as sidecars. |
| app.extraVolumeMounts | list | `[]` | List of extra mounts to add (normally used with extraVolumes). |
| app.extraVolumes | list | `[]` | List of extra volumes to add. |
| app.healthcheckPath | string | `"/"` | app container healthcheck endpoint. |
| app.hostAliases | list | `[]` | Host aliases that will be injected at pod-level into /etc/hosts. |
| app.image.pullPolicy | string | `"Always"` | Image pull policy for the app. |
| app.image.repository | string | `"docker.io/debian"` | Repository to use for the app. |
| app.image.tag | string | `""` | Tag to use for the app. Overrides the image tag whose default is the chart appVersion. |
| app.ingress.annotations | object | `{}` | Additional ingress annotations. |
| app.ingress.className | string | `""` | Defines which ingress controller will implement the resource. |
| app.ingress.enabled | bool | `true` | Whether or not ingress should be enabled. |
| app.ingress.hosts | list | `["domain.local"]` | The list of hosts to be covered by ingress record. |
| app.ingress.labels | object | `{}` | Additional ingress labels. |
| app.ingress.tls | list | `[]` | Enable TLS configuration. |
| app.initContainers | list | `[]` | Init containers to add to the app pod. |
| app.livenessProbe.enabled | bool | `true` | Whether or not enable the probe. |
| app.livenessProbe.failureThreshold | int | `3` | Minimum consecutive successes for the probe to be considered successful after having failed. |
| app.livenessProbe.initialDelaySeconds | int | `30` | Whether or not enable the probe. |
| app.livenessProbe.periodSeconds | int | `30` | Minimum consecutive failures for the probe to be considered failed after having succeeded. |
| app.livenessProbe.successThreshold | int | `1` | Number of seconds after the container has started before probe is initiated. |
| app.livenessProbe.timeoutSeconds | int | `5` | How often (in seconds) to perform the probe. |
| app.nodeSelector | object | `{}` | Default node selector for app. |
| app.podAnnotations | object | `{}` | Annotations for the app deployed pods. |
| app.podLabels | object | `{}` | Labels for the app deployed pods. |
| app.podSecurityContext | object | `{}` | Toggle and define pod-level security context. |
| app.readinessProbe.enabled | bool | `true` | Whether or not enable the probe. |
| app.readinessProbe.failureThreshold | int | `2` | Minimum consecutive failures for the probe to be considered failed after having succeeded. |
| app.readinessProbe.initialDelaySeconds | int | `15` | Number of seconds after the container has started before probe is initiated. |
| app.readinessProbe.periodSeconds | int | `10` | How often (in seconds) to perform the probe. |
| app.readinessProbe.successThreshold | int | `2` | Minimum consecutive successes for the probe to be considered successful after having failed. |
| app.readinessProbe.timeoutSeconds | int | `5` | Number of seconds after which the probe times out. |
| app.replicaCount | int | `1` | The number of application controller pods to run. |
| app.resources.limits.cpu | string | `"500m"` | CPU limit for the app. |
| app.resources.limits.memory | string | `"2Gi"` | Memory limit for the app. |
| app.resources.requests.cpu | string | `"100m"` | CPU request for the app. |
| app.resources.requests.memory | string | `"256Mi"` | Memory request for the app. |
| app.secrets | object | `{}` | app container env secrets, it will be injected into a secret and loaded into the container. |
| app.service.port | int | `80` | app service port. |
| app.service.type | string | `"ClusterIP"` | app service type. |
| app.serviceAccount.annotations | object | `{}` | Annotations applied to created service account. |
| app.serviceAccount.create | bool | `false` | Create a service account for the API. |
| app.serviceAccount.name | string | `"app-sa"` | Service account name. |
| app.startupProbe.enabled | bool | `true` | Whether or not enable the probe. |
| app.startupProbe.failureThreshold | int | `10` | Minimum consecutive failures for the probe to be considered failed after having succeeded. |
| app.startupProbe.initialDelaySeconds | int | `0` | Number of seconds after the container has started before probe is initiated. |
| app.startupProbe.periodSeconds | int | `10` | How often (in seconds) to perform the probe. |
| app.startupProbe.successThreshold | int | `1` | Minimum consecutive successes for the probe to be considered successful after having failed. |
| app.startupProbe.timeoutSeconds | int | `5` | Number of seconds after which the probe times out. |
| app.strategy.type | string | `"RollingUpdate"` | Strategy type used to replace old Pods by new ones, can be "Recreate" or "RollingUpdate". |
| app.tolerations | list | `[]` | Default tolerations for app. |

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

### Other Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| fullnameOverride | string | `""` | String to fully override the default application name. |
| nameOverride | string | `""` | Provide a name in place of the default application name. |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
