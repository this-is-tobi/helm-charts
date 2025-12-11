# chartname

![Version: 0.1.0](https://img.shields.io/badge/Version-0.1.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.1.0](https://img.shields.io/badge/AppVersion-0.1.0-informational?style=flat-square)

A Helm chart to deploy chartname.

## Values

### General

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| extraObjects | list | `[]` | Add extra specs dynamically to this chart. |
| fullnameOverride | string | `""` | String to fully override the default application name. |
| nameOverride | string | `""` | Provide a name in place of the default application name. |

### Global

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| global.env | object | `{}` | Map or array of environment variables to inject into all containers (`valueFrom` supported). |
| global.envCm | object | `{}` | Map of environment variables to inject into a configmap loaded by all containers (`valueFrom` not supported). |
| global.envSecret | object | `{}` | Map of environment variables to inject into a secret loaded by all containers (`valueFrom` not supported). |
| global.ingress | object | `{}` | Whether or not ingress should be enabled globally, it could be shared by all components that support ingress. |

### Servicename

#### General

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| servicename.affinity | object | `{}` | Affinity used for app pod. |
| servicename.args | list | `[]` | Servicename container command args. |
| servicename.command | list | `[]` | Servicename container command. |
| servicename.containerPort | int | `8080` | Servicename container port number. |
| servicename.containerPortName | string | `"http"` | Servicename container port name. |
| servicename.env | object | `{}` | Map or array of environment variables to inject into the app container (`valueFrom` supported). |
| servicename.envCm | object | `{}` | Map of environment variables to inject into a configmap loaded by the app container (`valueFrom` not supported). |
| servicename.envFrom | list | `[]` | Servicename container env variables loaded from configmap or secret reference. |
| servicename.envSecret | object | `{}` | Map of environment variables to inject into a secret loaded by the app container (`valueFrom` not supported). |
| servicename.extraContainers | list | `[]` | Extra containers to add to the app pod as sidecars. |
| servicename.extraPorts | list | `[]` | Servicename extra container ports. |
| servicename.hostAliases | list | `[]` | Host aliases that will be injected at pod-level into /etc/hosts. |
| servicename.imagePullSecrets | list | `[]` | Image credentials configuration. |
| servicename.initContainers | list | `[]` | Init containers to add to the app pod. |
| servicename.nodeSelector | object | `{}` | Default node selector for app. |
| servicename.podAnnotations | object | `{}` | Annotations for the app deployed pods. |
| servicename.podLabels | object | `{}` | Labels for the app deployed pods. |
| servicename.podSecurityContext | object | `{}` | Toggle and define pod-level security context. |
| servicename.replicaCount | int | `1` | The number of application controller pods to run. |
| servicename.revisionHistoryLimit | int | `10` | Revision history limit for the app. |
| servicename.securityContext | object | `{}` | Toggle and define container-level security context. |
| servicename.statefulset | bool | `false` | Should the app run as a StatefulSet instead of a Deployment. |
| servicename.tolerations | list | `[]` | Default tolerations for app. |
| servicename.volumeClaims | list | `[]` | List of volumeClaims to add. |
| servicename.volumeMounts | list | `[]` | List of mounts to add (normally used with `volumes` or `volumeClaims`). |
| servicename.volumes | list | `[]` | List of volumes to add. |

#### Autoscaling

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| servicename.autoscaling.enabled | bool | `false` | Enable Horizontal Pod Autoscaler for the app. |
| servicename.autoscaling.maxReplicas | int | `3` | Maximum number of replicas for the app. |
| servicename.autoscaling.minReplicas | int | `1` | Minimum number of replicas for the app. |
| servicename.autoscaling.targetCPUUtilizationPercentage | int | `80` | Average CPU utilization percentage for the app. |
| servicename.autoscaling.targetMemoryUtilizationPercentage | int | `80` | Average memory utilization percentage for the app. |

#### Image

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| servicename.image.pullPolicy | string | `"IfNotPresent"` | Image pull policy for the app. |
| servicename.image.repository | string | `"docker.io/debian"` | Repository to use for the app. |
| servicename.image.tag | string | `""` | Tag to use for the app. Overrides the image tag whose default is the chart appVersion. |

#### Ingress

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| servicename.ingress.annotations | object | `{}` | Additional ingress annotations. |
| servicename.ingress.className | string | `""` | Defines which ingress controller will implement the resource. |
| servicename.ingress.enabled | bool | `false` | Whether or not ingress should be enabled. |
| servicename.ingress.hosts[0].backend.portNumber | string | `nil` | Port used by the backend service linked to the host record (leave null to use the app service port). |
| servicename.ingress.hosts[0].backend.serviceName | string | `""` | Name of the backend service linked to the host record (leave empty to use the app service). |
| servicename.ingress.hosts[0].name | string | `"domain.local"` | Name of the host record. |
| servicename.ingress.hosts[0].path | string | `"/"` | Path of the host record to manage routing. |
| servicename.ingress.hosts[0].pathType | string | `"Prefix"` | Path type of the host record. |
| servicename.ingress.labels | object | `{}` | Additional ingress labels. |
| servicename.ingress.tls | list | `[]` | Enable TLS configuration. |

#### Metrics

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| servicename.metrics.enabled | bool | `false` | Deploy metrics service. |
| servicename.metrics.service.annotations | object | `{}` | Metrics service annotations. |
| servicename.metrics.service.labels | object | `{}` | Metrics service labels. |
| servicename.metrics.service.port | int | `9000` | Metrics service port. |
| servicename.metrics.service.targetPort | int | `9000` | Metrics service target port. |
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

#### NetworkPolicy

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| servicename.networkPolicy.create | bool | `false` | Create NetworkPolicy object for the app. |
| servicename.networkPolicy.egress | list | `[]` | Egress rules for the NetworkPolicy object. |
| servicename.networkPolicy.ingress | list | `[]` | Ingress rules for the NetworkPolicy object. |
| servicename.networkPolicy.policyTypes | list | `["Ingress"]` | Policy types used in the NetworkPolicy object. |

#### Pdb

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| servicename.pdb.annotations | object | `{}` | Annotations to be added to app pdb. |
| servicename.pdb.enabled | bool | `false` | Deploy a PodDisruptionBudget for the app |
| servicename.pdb.labels | object | `{}` | Labels to be added to app pdb. |
| servicename.pdb.maxUnavailable | string | `""` | Number of pods that are unavailable after eviction as number or percentage (eg.: 50%). Has higher precedence over `servicename.pdb.minAvailable`. |
| servicename.pdb.minAvailable | string | `""` (defaults to 0 if not specified) | Number of pods that are available after eviction as number or percentage (eg.: 50%). |

#### Probes

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| servicename.probes.livenessProbe.failureThreshold | int | `3` | Minimum consecutive failures for the probe to be considered failed after having succeeded. |
| servicename.probes.livenessProbe.httpGet.path | string | `"/"` | Servicename container healthcheck endpoint (livenessProbe is defined using `toYaml` so it is possible to override it completely). |
| servicename.probes.livenessProbe.httpGet.port | int | `8080` | Port to use for healthcheck (defaults to container port). |
| servicename.probes.livenessProbe.initialDelaySeconds | int | `30` | Number of seconds after the container has started before probe is initiated. |
| servicename.probes.livenessProbe.periodSeconds | int | `30` | How often (in seconds) to perform the probe. |
| servicename.probes.livenessProbe.successThreshold | int | `1` | Minimum consecutive successes for the probe to be considered successful after having failed. |
| servicename.probes.livenessProbe.timeoutSeconds | int | `5` | Number of seconds after which the probe times out. |
| servicename.probes.readinessProbe.failureThreshold | int | `2` | Minimum consecutive failures for the probe to be considered failed after having succeeded. |
| servicename.probes.readinessProbe.httpGet.path | string | `"/"` | Servicename container healthcheck endpoint (readinessProbe is defined using `toYaml` so it is possible to override it completely). |
| servicename.probes.readinessProbe.httpGet.port | int | `8080` | Port to use for healthcheck (defaults to container port). |
| servicename.probes.readinessProbe.initialDelaySeconds | int | `10` | Number of seconds after the container has started before probe is initiated. |
| servicename.probes.readinessProbe.periodSeconds | int | `10` | How often (in seconds) to perform the probe. |
| servicename.probes.readinessProbe.successThreshold | int | `2` | Minimum consecutive successes for the probe to be considered successful after having failed. |
| servicename.probes.readinessProbe.timeoutSeconds | int | `5` | Number of seconds after which the probe times out. |
| servicename.probes.startupProbe.failureThreshold | int | `10` | Minimum consecutive failures for the probe to be considered failed after having succeeded. |
| servicename.probes.startupProbe.httpGet.path | string | `"/"` | Servicename container healthcheck endpoint (startupProbe is defined using `toYaml` so it is possible to override it completely). |
| servicename.probes.startupProbe.httpGet.port | int | `8080` | Port to use for healthcheck (defaults to container port). |
| servicename.probes.startupProbe.initialDelaySeconds | int | `0` | Number of seconds after the container has started before probe is initiated. |
| servicename.probes.startupProbe.periodSeconds | int | `10` | How often (in seconds) to perform the probe. |
| servicename.probes.startupProbe.successThreshold | int | `1` | Minimum consecutive successes for the probe to be considered successful after having failed. |
| servicename.probes.startupProbe.timeoutSeconds | int | `5` | Number of seconds after which the probe times out. |

#### Resources

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| servicename.resources.limits.cpu | string | `"500m"` | CPU limit for the app. |
| servicename.resources.limits.memory | string | `"2Gi"` | Memory limit for the app. |
| servicename.resources.requests.cpu | string | `"100m"` | CPU request for the app. |
| servicename.resources.requests.memory | string | `"256Mi"` | Memory request for the app. |

#### Service

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| servicename.service.extraPorts | list | `[]` | Extra service ports. |
| servicename.service.nodePort | int | `31000` | Port used when type is `NodePort` to expose the service on the given node port. |
| servicename.service.port | int | `80` | Port used by the service. |
| servicename.service.portName | string | `"http"` | Port name used by the service. |
| servicename.service.protocol | string | `"TCP"` | Protocol used by the service. |
| servicename.service.type | string | `"ClusterIP"` | Type of service to create for the app. |

#### ServiceAccount

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| servicename.serviceAccount.annotations | object | `{}` | Annotations applied to created service account. |
| servicename.serviceAccount.automountServiceAccountToken | bool | `false` | Should the service account access token be automount in the pod. |
| servicename.serviceAccount.clusterRole.create | bool | `false` | Should the clusterRole be created. |
| servicename.serviceAccount.clusterRole.rules | list | `[]` | ClusterRole rules associated with the service account. |
| servicename.serviceAccount.create | bool | `false` | Create a service account. |
| servicename.serviceAccount.enabled | bool | `false` | Enable the service account. |
| servicename.serviceAccount.name | string | `""` | Service account name. |
| servicename.serviceAccount.role.create | bool | `false` | Should the role be created. |
| servicename.serviceAccount.role.rules | list | `[]` | Role rules associated with the service account. |

#### Strategy

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| servicename.strategy.rollingUpdate.maxSurge | int | `1` | The maximum number of pods that can be scheduled above the desired number of pods. |
| servicename.strategy.rollingUpdate.maxUnavailable | int | `1` | The maximum number of pods that can be unavailable during the update process. |
| servicename.strategy.type | string | `"RollingUpdate"` | Strategy type used to replace old Pods by new ones, can be `Recreate` or `RollingUpdate`. |

## Sources

**Source code:**

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
