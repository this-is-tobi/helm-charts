# backup-utils

![Version: 2.0.0](https://img.shields.io/badge/Version-2.0.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 1.0.0](https://img.shields.io/badge/AppVersion-1.0.0-informational?style=flat-square)

A Helm chart for effortless deployment of backup utilities (postgresql, s3 and vault).

## Installing the Chart

### CLI

```sh
helm repo add tobi https://this-is-tobi.github.io/helm-charts
helm install <release_name> tobi/backup-utils
```

### ArgoCD

`application.yaml` :

```yaml
[...]
sources:
- repoURL: https://this-is-tobi.github.io/helm-charts
  chart: backup-utils
  targetRevision: 2.0.0
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
- name: backup-utils
  version: 2.0.0
  repository: https://this-is-tobi.github.io/helm-charts
  condition: backup-utils.enabled
```

`values.yaml`:

```yaml
[...]
backup-utils:
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

### Postgresql

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| postgresql[0].container.args | list | `[]` | Postgresql backup container command args. |
| postgresql[0].container.command | list | `[]` | Postgresql backup container command. |
| postgresql[0].container.port | int | `8080` | Postgresql backup container port. |
| postgresql[0].container.securityContext | object | `{}` | Toggle and define container-level security context. |
| postgresql[0].enabled | bool | `false` | Whether or not postgresql backup should be enabled. |
| postgresql[0].env.MC_EXTRA_ARGS | string | `""` | Minio extra cli args used for backup. |
| postgresql[0].env.RETENTION | string | `"7d"` | Backup rentention to apply on the bucket, it should follow the pattern `#d#hh#mm#ss` (https://min.io/docs/minio/linux/reference/minio-mc/mc-rm.html#mc.rm.-older-than). |
| postgresql[0].env.S3_PATH_STYLE | string | `"true"` | Whether or not S3 path style is used (if the bucket name is included in the S3_ENDPOINT variable, the value should be set to "false"). |
| postgresql[0].envFrom | list | `[]` | Postgresql backup container env variables loaded from configmap or secret reference. |
| postgresql[0].image.pullPolicy | string | `"IfNotPresent"` | Image pull policy for the postgresql backup. |
| postgresql[0].image.repository | string | `"ghcr.io/this-is-tobi/tools/pg-backup"` | Repository to use for the postgresql backup. |
| postgresql[0].image.tag | string | `"3.4.0"` | Tag to use for the postgresql backup. Overrides the image tag whose default is the chart appVersion. |
| postgresql[0].job.backoffLimit | int | `3` | Specifies the number of retries before marking this job failed. |
| postgresql[0].job.concurrencyPolicy | string | `"Forbid"` | Specifies how to treat concurrent executions of a Job. Valid values are "Allow", "Forbid" and "Replace". |
| postgresql[0].job.failedJobsHistoryLimit | int | `3` | The number of failed finished jobs to retain. Value must be non-negative integer. |
| postgresql[0].job.schedule | string | `"0 0 * * *"` | The cron rule used for backups. By default it runs everyday at 00:00. |
| postgresql[0].job.successfulJobsHistoryLimit | int | `3` | The number of successful finished jobs to retain. Value must be non-negative integer. |
| postgresql[0].job.timeZone | string | `""` | The time zone name for the given schedule, see https://en.wikipedia.org/wiki/List_of_tz_database_time_zones. |
| postgresql[0].jobAnnotations | object | `{}` | Annotations for the postgresql backup deployed jobs. |
| postgresql[0].jobLabels | object | `{}` | Labels for the postgresql backup deployed jobs. |
| postgresql[0].podAnnotations | object | `{}` | Annotations for the postgresql backup deployed pods. |
| postgresql[0].podLabels | object | `{}` | Labels for the postgresql backup deployed pods. |
| postgresql[0].podSecurityContext | object | `{}` | Toggle and define pod-level security context. |
| postgresql[0].resources.limits.cpu | string | `"250m"` | CPU limit for the postgresql backup. |
| postgresql[0].resources.limits.memory | string | `"512Mi"` | Memory limit for the postgresql backup. |
| postgresql[0].resources.requests.cpu | string | `"100m"` | CPU request for the postgresql backup. |
| postgresql[0].resources.requests.memory | string | `"128Mi"` | Memory request for the postgresql backup. |
| postgresql[0].restartPolicy | string | `"Never"` | Restart policy for all containers within the pod. |
| postgresql[0].secrets.DB_HOST | string | `""` | Host of the postgresql database to backup. |
| postgresql[0].secrets.DB_NAME | string | `""` | Name of the postgresql database to backup. |
| postgresql[0].secrets.DB_PASS | string | `""` | Password of the postgresql database used for backup. |
| postgresql[0].secrets.DB_PORT | string | `""` | Port of the postgresql database to backup. |
| postgresql[0].secrets.DB_USER | string | `""` | User of the postgresql database used for backup. |
| postgresql[0].secrets.S3_ACCESS_KEY | string | `""` | S3 access key. |
| postgresql[0].secrets.S3_BUCKET_NAME | string | `""` | S3 bucket name used as target destination. |
| postgresql[0].secrets.S3_BUCKET_PREFIX | string | `""` | S3 bucket prefix used as target destination (the folder prefix used in the bucket). |
| postgresql[0].secrets.S3_ENDPOINT | string | `""` | S3 endpoint used as target destination. |
| postgresql[0].secrets.S3_SECRET_KEY | string | `""` | S3 secret key. |

### S3

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| s3[0].container.args | list | `[]` | S3 backup container command args. |
| s3[0].container.command | list | `[]` | S3 backup container command. |
| s3[0].container.port | int | `8080` | S3 backup container port. |
| s3[0].container.securityContext | object | `{}` | Toggle and define container-level security context. |
| s3[0].enabled | bool | `false` | Whether or not s3 backup should be enabled. |
| s3[0].env.MC_EXTRA_ARGS | string | `""` | Minio extra cli args used for backup. |
| s3[0].env.S3_PATH_STYLE | string | `"true"` | Whether or not S3 path style is used (if the bucket name is included in the S3_ENDPOINT variable, the value should be set to "false"). |
| s3[0].envFrom | list | `[]` | S3 backup container env variables loaded from configmap or secret reference. |
| s3[0].image.pullPolicy | string | `"IfNotPresent"` | Image pull policy for the s3 backup. |
| s3[0].image.repository | string | `"ghcr.io/this-is-tobi/tools/s3-backup"` | Repository to use for the s3 backup. |
| s3[0].image.tag | string | `"1.2.0"` | Tag to use for the s3 backup. Overrides the image tag whose default is the chart appVersion. |
| s3[0].job.backoffLimit | int | `3` | Specifies the number of retries before marking this job failed. |
| s3[0].job.concurrencyPolicy | string | `"Forbid"` | Specifies how to treat concurrent executions of a Job. Valid values are "Allow", "Forbid" and "Replace". |
| s3[0].job.failedJobsHistoryLimit | int | `3` | The number of failed finished jobs to retain. Value must be non-negative integer. |
| s3[0].job.schedule | string | `"0 0 * * *"` | The cron rule used for backups. By default it runs everyday at 00:00. |
| s3[0].job.successfulJobsHistoryLimit | int | `3` | The number of successful finished jobs to retain. Value must be non-negative integer. |
| s3[0].job.timeZone | string | `""` | The time zone name for the given schedule, see https://en.wikipedia.org/wiki/List_of_tz_database_time_zones. |
| s3[0].jobAnnotations | object | `{}` | Annotations for the s3 backup deployed jobs. |
| s3[0].jobLabels | object | `{}` | Labels for the s3 backup deployed jobs. |
| s3[0].podAnnotations | object | `{}` | Annotations for the s3 backup deployed pods. |
| s3[0].podLabels | object | `{}` | Labels for the s3 backup deployed pods. |
| s3[0].podSecurityContext | object | `{}` | Toggle and define pod-level security context. |
| s3[0].resources.limits.cpu | string | `"250m"` | CPU limit for the s3 backup. |
| s3[0].resources.limits.memory | string | `"512Mi"` | Memory limit for the s3 backup. |
| s3[0].resources.requests.cpu | string | `"100m"` | CPU request for the s3 backup. |
| s3[0].resources.requests.memory | string | `"128Mi"` | Memory request for the s3 backup. |
| s3[0].restartPolicy | string | `"Never"` | Restart policy for all containers within the pod. |
| s3[0].secrets.SOURCE_S3_ACCESS_KEY | string | `""` | S3 source access key. |
| s3[0].secrets.SOURCE_S3_BUCKET_NAME | string | `""` | S3 source bucket name used as target destination. |
| s3[0].secrets.SOURCE_S3_BUCKET_PREFIX | string | `""` | S3 source bucket prefix used as target destination (the folder prefix used in the bucket). |
| s3[0].secrets.SOURCE_S3_ENDPOINT | string | `""` | S3 source endpoint used as target destination. |
| s3[0].secrets.SOURCE_S3_SECRET_KEY | string | `""` | S3 source secret key. |
| s3[0].secrets.TARGET_S3_ACCESS_KEY | string | `""` | S3 target access key. |
| s3[0].secrets.TARGET_S3_BUCKET_NAME | string | `""` | S3 target bucket name used as target destination. |
| s3[0].secrets.TARGET_S3_BUCKET_PREFIX | string | `""` | S3 target bucket prefix used as target destination (the folder prefix used in the bucket). |
| s3[0].secrets.TARGET_S3_ENDPOINT | string | `""` | S3 target endpoint used as target destination. |
| s3[0].secrets.TARGET_S3_SECRET_KEY | string | `""` | S3 target secret key. |

### Vault

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| vault[0].container.args | list | `[]` | Vault backup container command args. |
| vault[0].container.command | list | `[]` | Vault backup container command. |
| vault[0].container.port | int | `8080` | Vault backup container port. |
| vault[0].container.securityContext | object | `{}` | Toggle and define container-level security context. |
| vault[0].enabled | bool | `false` | Whether or not vault backup should be enabled. |
| vault[0].env.MC_EXTRA_ARGS | string | `""` | Minio extra cli args used for backup. |
| vault[0].env.RETENTION | string | `"7d"` | Backup rentention to apply on the bucket, it should follow the pattern `#d#hh#mm#ss` (https://min.io/docs/minio/linux/reference/minio-mc/mc-rm.html#mc.rm.-older-than). |
| vault[0].env.S3_PATH_STYLE | string | `"true"` | Whether or not S3 path style is used (if the bucket name is included in the S3_ENDPOINT variable, the value should be set to "false"). |
| vault[0].envFrom | list | `[]` | Vault backup container env variables loaded from configmap or secret reference. |
| vault[0].image.pullPolicy | string | `"IfNotPresent"` | Image pull policy for the vault backup. |
| vault[0].image.repository | string | `"ghcr.io/this-is-tobi/tools/vault-backup"` | Repository to use for the vault backup. |
| vault[0].image.tag | string | `"1.5.1"` | Tag to use for the vault backup. Overrides the image tag whose default is the chart appVersion. |
| vault[0].job.backoffLimit | int | `3` | Specifies the number of retries before marking this job failed. |
| vault[0].job.concurrencyPolicy | string | `"Forbid"` | Specifies how to treat concurrent executions of a Job. Valid values are "Allow", "Forbid" and "Replace". |
| vault[0].job.failedJobsHistoryLimit | int | `3` | The number of failed finished jobs to retain. Value must be non-negative integer. |
| vault[0].job.schedule | string | `"0 0 * * *"` | The cron rule used for backups. By default it runs everyday at 00:00. |
| vault[0].job.successfulJobsHistoryLimit | int | `3` | The number of successful finished jobs to retain. Value must be non-negative integer. |
| vault[0].job.timeZone | string | `""` | The time zone name for the given schedule, see https://en.wikipedia.org/wiki/List_of_tz_database_time_zones. |
| vault[0].jobAnnotations | object | `{}` | Annotations for the vault backup deployed jobs. |
| vault[0].jobLabels | object | `{}` | Labels for the vault backup deployed jobs. |
| vault[0].podAnnotations | object | `{}` | Annotations for the vault backup deployed pods. |
| vault[0].podLabels | object | `{}` | Labels for the vault backup deployed pods. |
| vault[0].podSecurityContext | object | `{}` | Toggle and define pod-level security context. |
| vault[0].resources.limits.cpu | string | `"250m"` | CPU limit for the vault backup. |
| vault[0].resources.limits.memory | string | `"512Mi"` | Memory limit for the vault backup. |
| vault[0].resources.requests.cpu | string | `"100m"` | CPU request for the vault backup. |
| vault[0].resources.requests.memory | string | `"128Mi"` | Memory request for the vault backup. |
| vault[0].restartPolicy | string | `"Never"` | Restart policy for all containers within the pod. |
| vault[0].secrets.S3_ACCESS_KEY | string | `""` | S3 access key. |
| vault[0].secrets.S3_BUCKET_NAME | string | `""` | S3 bucket name used as target destination. |
| vault[0].secrets.S3_BUCKET_PREFIX | string | `""` | S3 bucket prefix used as target destination (the folder prefix used in the bucket). |
| vault[0].secrets.S3_ENDPOINT | string | `""` | S3 endpoint used as target destination. |
| vault[0].secrets.S3_SECRET_KEY | string | `""` | S3 secret key. |
| vault[0].secrets.VAULT_ADDR | string | `""` | Host of the vault server to backup. |
| vault[0].secrets.VAULT_EXTRA_ARGS | string | `""` | Vault extra cli args used for backup. |
| vault[0].secrets.VAULT_TOKEN | string | `""` | Token of the vault server used for backup. |

### Other Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| fullnameOverride | string | `""` | String to fully override the default application name. |
| nameOverride | string | `""` | Provide a name in place of the default application name. |

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| this-is-tobi | <this-is-tobi@proton.me> | <https://this-is-tobi.com> |

## Sources

**Source code:**

* <https://github.com/this-is-tobi/helm-charts>
* <https://github.com/this-is-tobi/tools>

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
