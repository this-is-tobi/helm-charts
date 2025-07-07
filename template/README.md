# chartname

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.1.0](https://img.shields.io/badge/AppVersion-0.1.0-informational?style=flat-square)

A Helm chart to deploy chartname.

## Installing the Chart

### CLI

```sh
helm repo add tobi https://this-is-tobi.github.io/helm-charts
helm install <release_name> tobi/chartname
```

### ArgoCD

`application.yaml` :

```yaml
[...]
sources:
- repoURL: https://this-is-tobi.github.io/helm-charts
  chart: chartname
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
- name: chartname
  version: 0.1.0
  repository: https://this-is-tobi.github.io/helm-charts
  condition: chartname.enabled
```

`values.yaml`:

```yaml
[...]
chartname:
  enabled: true
```

## Values

### Extras

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| extraObjects | list | `[]` | Add extra specs dynamically to this chart. |

### Global

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| global.env | object | `{}` | Map of environment variables to inject into backend and frontend containers. |
| global.secrets | object | `{}` | Map of environment variables to inject into backend and frontend containers. |

### App

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| servicename.affinity | object | `{}` | Affinity used for app pod. |
| servicename.autoscaling.enabled | bool | `false` | Enable Horizontal Pod Autoscaler ([HPA]) for the app. |
| servicename.autoscaling.maxReplicas | int | `3` | Maximum number of replicas for the app [HPA]. |
| servicename.autoscaling.minReplicas | int | `1` | Minimum number of replicas for the app [HPA]. |
| servicename.autoscaling.targetCPUUtilizationPercentage | int | `80` | Average CPU utilization percentage for the app [HPA]. |
| servicename.autoscaling.targetMemoryUtilizationPercentage | int | `80` | Average memory utilization percentage for the app [HPA]. |
| servicename.container.args | list | `[]` | app container command args. |
| servicename.container.command | list | `[]` | app container command. |
| servicename.container.port | int | `8080` | app container port. |
| servicename.container.securityContext | object | `{}` | Toggle and define container-level security context. |
| servicename.env | object | `{}` | app container env variables, it will be injected into a configmap and loaded into the container. |
| servicename.envFrom | list | `[]` | app container env variables loaded from configmap or secret reference. |
| servicename.extraContainers | list | `[]` | Extra containers to add to the app pod as sidecars. |
| servicename.healthcheckPath | string | `"/"` | app container healthcheck endpoint. |
| servicename.hostAliases | list | `[]` | Host aliases that will be injected at pod-level into /etc/hosts. |
| servicename.image.pullPolicy | string | `"IfNotPresent"` | Image pull policy for the app. |
| servicename.image.repository | string | `"docker.io/debian"` | Repository to use for the app. |
| servicename.image.tag | string | `""` | Tag to use for the app. Overrides the image tag whose default is the chart appVersion. |
| servicename.imagePullSecrets | list | `[]` | Image credentials configuration. |
| servicename.ingress.annotations | object | `{}` | Additional ingress annotations. |
| servicename.ingress.className | string | `""` | Defines which ingress controller will implement the resource. |
| servicename.ingress.enabled | bool | `true` | Whether or not ingress should be enabled. |
| servicename.ingress.hosts[0].backend.portNumber | string | `nil` | Port used by the backend service linked to the host record. |
| servicename.ingress.hosts[0].backend.serviceName | string | `""` | Name of the backend service linked to the host record. |
| servicename.ingress.hosts[0].name | string | `"domain.local"` | Name of the host record. |
| servicename.ingress.hosts[0].path | string | `"/"` | Path of the host record to manage routing. |
| servicename.ingress.hosts[0].pathType | string | `"Prefix"` | Path type of the host record. |
| servicename.ingress.labels | object | `{}` | Additional ingress labels. |
| servicename.ingress.tls | list | `[]` | Enable TLS configuration. |
| servicename.initContainers | list | `[]` | Init containers to add to the app pod. |
| servicename.livenessProbe.enabled | bool | `true` | Whether or not enable the probe. |
| servicename.livenessProbe.failureThreshold | int | `3` | Minimum consecutive failures for the probe to be considered failed after having succeeded. |
| servicename.livenessProbe.initialDelaySeconds | int | `30` | Number of seconds after the container has started before probe is initiated. |
| servicename.livenessProbe.periodSeconds | int | `30` | How often (in seconds) to perform the probe. |
| servicename.livenessProbe.successThreshold | int | `1` | Minimum consecutive successes for the probe to be considered successful after having failed. |
| servicename.livenessProbe.timeoutSeconds | int | `5` | Number of seconds after which the probe times out. |
| servicename.metrics.enabled | bool | `false` | Deploy metrics service. |
| servicename.metrics.service.annotations | object | `{}` | Metrics service annotations. |
| servicename.metrics.service.labels | object | `{}` | Metrics service labels. |
| servicename.metrics.service.port | int | `8080` | Metrics service port. |
| servicename.metrics.service.targetPort | int | `8080` | Metrics service target port. |
| servicename.metrics.serviceMonitor.annotations | object | `{}` | Prometheus ServiceMonitor annotations. |
| servicename.metrics.serviceMonitor.enabled | bool | `false` | Enable a prometheus ServiceMonitor. |
| servicename.metrics.serviceMonitor.endpoints[0].basicAuth.password | string | `""` | The secret in the service monitor namespace that contains the password for authentication. |
| servicename.metrics.serviceMonitor.endpoints[0].basicAuth.username | string | `""` | The secret in the service monitor namespace that contains the username for authentication. |
| servicename.metrics.serviceMonitor.endpoints[0].bearerTokenSecret.key | string | `""` | Secret key to mount to read bearer token for scraping targets. The secret needs to be in the same namespace as the service monitor and accessible by the Prometheus Operator. |
| servicename.metrics.serviceMonitor.endpoints[0].bearerTokenSecret.name | string | `""` | Secret name to mount to read bearer token for scraping targets. The secret needs to be in the same namespace as the service monitor and accessible by the Prometheus Operator. |
| servicename.metrics.serviceMonitor.endpoints[0].honorLabels | bool | `false` | When true, honorLabels preserves the metric’s labels when they collide with the target’s labels. |
| servicename.metrics.serviceMonitor.endpoints[0].interval | string | `"30s"` | Prometheus ServiceMonitor interval. |
| servicename.metrics.serviceMonitor.endpoints[0].metricRelabelings | list | `[]` | Prometheus MetricRelabelConfigs to apply to samples before ingestion. |
| servicename.metrics.serviceMonitor.endpoints[0].path | string | `"/metrics"` | Path used by the Prometheus ServiceMonitor to scrape metrics. |
| servicename.metrics.serviceMonitor.endpoints[0].relabelings | list | `[]` | Prometheus RelabelConfigs to apply to samples before scraping. |
| servicename.metrics.serviceMonitor.endpoints[0].scheme | string | `""` | Prometheus ServiceMonitor scheme. |
| servicename.metrics.serviceMonitor.endpoints[0].scrapeTimeout | string | `"10s"` | Prometheus ServiceMonitor scrapeTimeout. If empty, Prometheus uses the global scrape timeout unless it is less than the target's scrape interval value in which the latter is used. |
| servicename.metrics.serviceMonitor.endpoints[0].selector | object | `{}` | Prometheus ServiceMonitor selector. |
| servicename.metrics.serviceMonitor.endpoints[0].tlsConfig | object | `{}` | Prometheus ServiceMonitor tlsConfig. |
| servicename.metrics.serviceMonitor.labels | object | `{}` | Prometheus ServiceMonitor labels. |
| servicename.networkPolicy.create | bool | `false` | Create NetworkPolicy object for the app. |
| servicename.networkPolicy.egress | list | `[]` | Egress rules for the NetworkPolicy object. |
| servicename.networkPolicy.ingress | list | `[]` | Ingress rules for the NetworkPolicy object. |
| servicename.networkPolicy.policyTypes | list | `["Ingress"]` | Policy types used in the NetworkPolicy object. |
| servicename.nodeSelector | object | `{}` | Default node selector for app. |
| servicename.pdb.annotations | object | `{}` | Annotations to be added to app pdb. |
| servicename.pdb.enabled | bool | `false` | Deploy a PodDisruptionBudget for the app |
| servicename.pdb.labels | object | `{}` | Labels to be added to app pdb. |
| servicename.pdb.maxUnavailable | string | `""` | Number of pods that are unavailable after eviction as number or percentage (eg.: 50%). # Has higher precedence over `server.pdb.minAvailable` |
| servicename.pdb.minAvailable | string | `""` (defaults to 0 if not specified) | Number of pods that are available after eviction as number or percentage (eg.: 50%). |
| servicename.podAnnotations | object | `{}` | Annotations for the app deployed pods. |
| servicename.podLabels | object | `{}` | Labels for the app deployed pods. |
| servicename.podSecurityContext | object | `{}` | Toggle and define pod-level security context. |
| servicename.readinessProbe.enabled | bool | `true` | Whether or not enable the probe. |
| servicename.readinessProbe.failureThreshold | int | `2` | Minimum consecutive failures for the probe to be considered failed after having succeeded. |
| servicename.readinessProbe.initialDelaySeconds | int | `10` | Number of seconds after the container has started before probe is initiated. |
| servicename.readinessProbe.periodSeconds | int | `10` | How often (in seconds) to perform the probe. |
| servicename.readinessProbe.successThreshold | int | `2` | Minimum consecutive successes for the probe to be considered successful after having failed. |
| servicename.readinessProbe.timeoutSeconds | int | `5` | Number of seconds after which the probe times out. |
| servicename.replicaCount | int | `1` | The number of application controller pods to run. |
| servicename.resources.limits.cpu | string | `"500m"` | CPU limit for the app. |
| servicename.resources.limits.memory | string | `"2Gi"` | Memory limit for the app. |
| servicename.resources.requests.cpu | string | `"100m"` | CPU request for the app. |
| servicename.resources.requests.memory | string | `"256Mi"` | Memory request for the app. |
| servicename.secrets | object | `{}` | app container env secrets, it will be injected into a secret and loaded into the container. |
| servicename.service.port | int | `80` | app service port. |
| servicename.service.type | string | `"ClusterIP"` | app service type. |
| servicename.serviceAccount.annotations | object | `{}` | Annotations applied to created service account. |
| servicename.serviceAccount.automountServiceAccountToken | bool | `false` | Should the service account access token be automount in the pod. |
| servicename.serviceAccount.clusterRole.create | bool | `false` | Should the clusterRole be created. |
| servicename.serviceAccount.clusterRole.rules | list | `[]` | ClusterRole rules associated with the service account. |
| servicename.serviceAccount.create | bool | `false` | Create a service account. |
| servicename.serviceAccount.enabled | bool | `false` | Enable the service account. |
| servicename.serviceAccount.name | string | `""` | Service account name. |
| servicename.serviceAccount.role.create | bool | `false` | Should the role be created. |
| servicename.serviceAccount.role.rules | list | `[]` | Role rules associated with the service account. |
| servicename.startupProbe.enabled | bool | `true` | Whether or not enable the probe. |
| servicename.startupProbe.failureThreshold | int | `10` | Minimum consecutive failures for the probe to be considered failed after having succeeded. |
| servicename.startupProbe.initialDelaySeconds | int | `0` | Number of seconds after the container has started before probe is initiated. |
| servicename.startupProbe.periodSeconds | int | `10` | How often (in seconds) to perform the probe. |
| servicename.startupProbe.successThreshold | int | `1` | Minimum consecutive successes for the probe to be considered successful after having failed. |
| servicename.startupProbe.timeoutSeconds | int | `5` | Number of seconds after which the probe times out. |
| servicename.statefulset | bool | `false` | Should the app run as a StatefulSet instead of a Deployment. |
| servicename.strategy.type | string | `"RollingUpdate"` | Strategy type used to replace old Pods by new ones, can be "Recreate" or "RollingUpdate". |
| servicename.tolerations | list | `[]` | Default tolerations for app. |
| servicename.volumeClaims | list | `[]` | List of volumeClaims to add. |
| servicename.volumeMounts | list | `[]` | List of mounts to add (normally used with `volumes` or `volumeClaims`). |
| servicename.volumes | list | `[]` | List of volumes to add. |

### Other Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| fullnameOverride | string | `""` | String to fully override the default application name. |
| nameOverride | string | `""` | Provide a name in place of the default application name. |

## Sources

**Source code:**

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
