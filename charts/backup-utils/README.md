# backup-utils

![Version: 1.1.2](https://img.shields.io/badge/Version-1.1.2-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.1.0](https://img.shields.io/badge/AppVersion-0.1.0-informational?style=flat-square)

A Helm chart for effortless deployment of backup utilities.

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| this-is-tobi | <this-is-tobi@proton.me> | <https://this-is-tobi.com> |

## Source Code

* <https://github.com/this-is-tobi/helm-charts>
* <https://github.com/this-is-tobi/tools>

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| fullnameOverride | string | `""` | String to fully override the default application name. |
| global.env | object | `{}` | Map of environment variables to inject into backend and frontend containers. |
| global.secrets | object | `{}` | Map of environment variables to inject into backend and frontend containers. |
| imageCredentials.email | string | `""` | Email to pull images. |
| imageCredentials.password | string | `""` | Password to pull images. |
| imageCredentials.registry | string | `""` | Registry to pull images from. |
| imageCredentials.username | string | `""` | Username to pull images. |
| nameOverride | string | `""` | Provide a name in place of the default application name. |
| postgresql.container.args | list | `[]` | Postgresql backup container command args. |
| postgresql.container.command | list | `[]` | Postgresql backup container command. |
| postgresql.container.port | int | `8080` | Postgresql backup container port. |
| postgresql.container.securityContext | object | `{}` | Toggle and define container-level security context. |
| postgresql.enabled | bool | `false` | Whether or not postgresql backup should be enabled. |
| postgresql.env.MC_EXTRA_ARGS | string | `""` | Minio extra cli args used for backup. |
| postgresql.env.RETENTION | string | `"7d"` | Backup rentention to apply on the bucket, it should follow the pattern `#d#hh#mm#ss` (https://min.io/docs/minio/linux/reference/minio-mc/mc-rm.html#mc.rm.-older-than). |
| postgresql.envFrom | list | `[]` | Postgresql backup container env variables loaded from configmap or secret reference. |
| postgresql.image.pullPolicy | string | `"IfNotPresent"` | Image pull policy for the postgresql backup. |
| postgresql.image.repository | string | `"ghcr.io/this-is-tobi/tools/pg-backup"` | Repository to use for the postgresql backup. |
| postgresql.image.tag | string | `"3.0.2"` | Tag to use for the postgresql backup. Overrides the image tag whose default is the chart appVersion. |
| postgresql.job.backoffLimit | int | `3` | Specifies the number of retries before marking this job failed. |
| postgresql.job.concurrencyPolicy | string | `"Forbid"` | Specifies how to treat concurrent executions of a Job. Valid values are "Allow", "Forbid" and "Replace". |
| postgresql.job.failedJobsHistoryLimit | int | `3` | The number of failed finished jobs to retain. Value must be non-negative integer. |
| postgresql.job.schedule | string | `"0 0 * * *"` | The cron rule used for backups. By default it runs everyday at 00:00. |
| postgresql.job.successfulJobsHistoryLimit | int | `3` | The number of successful finished jobs to retain. Value must be non-negative integer. |
| postgresql.job.timeZone | string | `""` | The time zone name for the given schedule, see https://en.wikipedia.org/wiki/List_of_tz_database_time_zones. |
| postgresql.jobAnnotations | object | `{}` | Annotations for the postgresql backup deployed jobs. |
| postgresql.jobLabels | object | `{}` | Labels for the postgresql backup deployed jobs. |
| postgresql.podAnnotations | object | `{}` | Annotations for the postgresql backup deployed pods. |
| postgresql.podLabels | object | `{}` | Labels for the postgresql backup deployed pods. |
| postgresql.podSecurityContext | object | `{}` | Toggle and define pod-level security context. |
| postgresql.resources.limits.cpu | string | `"250m"` | CPU limit for the postgresql backup. |
| postgresql.resources.limits.memory | string | `"512Mi"` | Memory limit for the postgresql backup. |
| postgresql.resources.requests.cpu | string | `"100m"` | CPU request for the postgresql backup. |
| postgresql.resources.requests.memory | string | `"128Mi"` | Memory request for the postgresql backup. |
| postgresql.restartPolicy | string | `"Never"` | Restart policy for all containers within the pod. |
| postgresql.secrets.DB_HOST | string | `""` | Host of the postgresql database to backup. |
| postgresql.secrets.DB_NAME | string | `""` | Name of the postgresql database to backup. |
| postgresql.secrets.DB_PASS | string | `""` | Password of the postgresql database used for backup. |
| postgresql.secrets.DB_PORT | string | `""` | Port of the postgresql database to backup. |
| postgresql.secrets.DB_USER | string | `""` | User of the postgresql database used for backup. |
| postgresql.secrets.S3_ACCESS_KEY | string | `""` | S3 access key. |
| postgresql.secrets.S3_BUCKET_NAME | string | `""` | S3 bucket name used as target destination. |
| postgresql.secrets.S3_BUCKET_PREFIX | string | `""` | S3 bucket prefix used as target destination (the folder prefix used in the bucket). |
| postgresql.secrets.S3_ENDPOINT | string | `""` | S3 endpoint used as target destination. |
| postgresql.secrets.S3_SECRET_KEY | string | `""` | S3 secret key. |
| s3.container.args | list | `[]` | S3 backup container command args. |
| s3.container.command | list | `[]` | S3 backup container command. |
| s3.container.port | int | `8080` | S3 backup container port. |
| s3.container.securityContext | object | `{}` | Toggle and define container-level security context. |
| s3.enabled | bool | `false` | Whether or not s3 backup should be enabled. |
| s3.env.MC_EXTRA_ARGS | string | `""` | Minio extra cli args used for backup. |
| s3.envFrom | list | `[]` | S3 backup container env variables loaded from configmap or secret reference. |
| s3.image.pullPolicy | string | `"IfNotPresent"` | Image pull policy for the s3 backup. |
| s3.image.repository | string | `"ghcr.io/this-is-tobi/tools/s3-backup"` | Repository to use for the s3 backup. |
| s3.image.tag | string | `"1.1.4"` | Tag to use for the s3 backup. Overrides the image tag whose default is the chart appVersion. |
| s3.job.backoffLimit | int | `3` | Specifies the number of retries before marking this job failed. |
| s3.job.concurrencyPolicy | string | `"Forbid"` | Specifies how to treat concurrent executions of a Job. Valid values are "Allow", "Forbid" and "Replace". |
| s3.job.failedJobsHistoryLimit | int | `3` | The number of failed finished jobs to retain. Value must be non-negative integer. |
| s3.job.schedule | string | `"0 0 * * *"` | The cron rule used for backups. By default it runs everyday at 00:00. |
| s3.job.successfulJobsHistoryLimit | int | `3` | The number of successful finished jobs to retain. Value must be non-negative integer. |
| s3.job.timeZone | string | `""` | The time zone name for the given schedule, see https://en.wikipedia.org/wiki/List_of_tz_database_time_zones. |
| s3.jobAnnotations | object | `{}` | Annotations for the s3 backup deployed jobs. |
| s3.jobLabels | object | `{}` | Labels for the s3 backup deployed jobs. |
| s3.podAnnotations | object | `{}` | Annotations for the s3 backup deployed pods. |
| s3.podLabels | object | `{}` | Labels for the s3 backup deployed pods. |
| s3.podSecurityContext | object | `{}` | Toggle and define pod-level security context. |
| s3.resources.limits.cpu | string | `"250m"` | CPU limit for the s3 backup. |
| s3.resources.limits.memory | string | `"512Mi"` | Memory limit for the s3 backup. |
| s3.resources.requests.cpu | string | `"100m"` | CPU request for the s3 backup. |
| s3.resources.requests.memory | string | `"128Mi"` | Memory request for the s3 backup. |
| s3.restartPolicy | string | `"Never"` | Restart policy for all containers within the pod. |
| s3.secrets.SOURCE_S3_ACCESS_KEY | string | `""` | S3 source access key. |
| s3.secrets.SOURCE_S3_BUCKET_NAME | string | `""` | S3 source bucket name used as target destination. |
| s3.secrets.SOURCE_S3_BUCKET_PREFIX | string | `""` | S3 source bucket prefix used as target destination (the folder prefix used in the bucket). |
| s3.secrets.SOURCE_S3_ENDPOINT | string | `""` | S3 source endpoint used as target destination. |
| s3.secrets.SOURCE_S3_SECRET_KEY | string | `""` | S3 source secret key. |
| s3.secrets.TARGET_S3_ACCESS_KEY | string | `""` | S3 target access key. |
| s3.secrets.TARGET_S3_BUCKET_NAME | string | `""` | S3 target bucket name used as target destination. |
| s3.secrets.TARGET_S3_BUCKET_PREFIX | string | `""` | S3 target bucket prefix used as target destination (the folder prefix used in the bucket). |
| s3.secrets.TARGET_S3_ENDPOINT | string | `""` | S3 target endpoint used as target destination. |
| s3.secrets.TARGET_S3_SECRET_KEY | string | `""` | S3 target secret key. |
| vault.container.args | list | `[]` | Vault backup container command args. |
| vault.container.command | list | `[]` | Vault backup container command. |
| vault.container.port | int | `8080` | Vault backup container port. |
| vault.container.securityContext | object | `{}` | Toggle and define container-level security context. |
| vault.enabled | bool | `false` | Whether or not vault backup should be enabled. |
| vault.env.MC_EXTRA_ARGS | string | `""` | Minio extra cli args used for backup. |
| vault.env.RETENTION | string | `"7d"` | Backup rentention to apply on the bucket, it should follow the pattern `#d#hh#mm#ss` (https://min.io/docs/minio/linux/reference/minio-mc/mc-rm.html#mc.rm.-older-than). |
| vault.envFrom | list | `[]` | Vault backup container env variables loaded from configmap or secret reference. |
| vault.image.pullPolicy | string | `"IfNotPresent"` | Image pull policy for the vault backup. |
| vault.image.repository | string | `"ghcr.io/this-is-tobi/tools/vault-backup"` | Repository to use for the vault backup. |
| vault.image.tag | string | `"1.2.3"` | Tag to use for the vault backup. Overrides the image tag whose default is the chart appVersion. |
| vault.job.backoffLimit | int | `3` | Specifies the number of retries before marking this job failed. |
| vault.job.concurrencyPolicy | string | `"Forbid"` | Specifies how to treat concurrent executions of a Job. Valid values are "Allow", "Forbid" and "Replace". |
| vault.job.failedJobsHistoryLimit | int | `3` | The number of failed finished jobs to retain. Value must be non-negative integer. |
| vault.job.schedule | string | `"0 0 * * *"` | The cron rule used for backups. By default it runs everyday at 00:00. |
| vault.job.successfulJobsHistoryLimit | int | `3` | The number of successful finished jobs to retain. Value must be non-negative integer. |
| vault.job.timeZone | string | `""` | The time zone name for the given schedule, see https://en.wikipedia.org/wiki/List_of_tz_database_time_zones. |
| vault.jobAnnotations | object | `{}` | Annotations for the vault backup deployed jobs. |
| vault.jobLabels | object | `{}` | Labels for the vault backup deployed jobs. |
| vault.podAnnotations | object | `{}` | Annotations for the vault backup deployed pods. |
| vault.podLabels | object | `{}` | Labels for the vault backup deployed pods. |
| vault.podSecurityContext | object | `{}` | Toggle and define pod-level security context. |
| vault.resources.limits.cpu | string | `"250m"` | CPU limit for the vault backup. |
| vault.resources.limits.memory | string | `"512Mi"` | Memory limit for the vault backup. |
| vault.resources.requests.cpu | string | `"100m"` | CPU request for the vault backup. |
| vault.resources.requests.memory | string | `"128Mi"` | Memory request for the vault backup. |
| vault.restartPolicy | string | `"Never"` | Restart policy for all containers within the pod. |
| vault.secrets.S3_ACCESS_KEY | string | `""` | S3 access key. |
| vault.secrets.S3_BUCKET_NAME | string | `""` | S3 bucket name used as target destination. |
| vault.secrets.S3_BUCKET_PREFIX | string | `""` | S3 bucket prefix used as target destination (the folder prefix used in the bucket). |
| vault.secrets.S3_ENDPOINT | string | `""` | S3 endpoint used as target destination. |
| vault.secrets.S3_SECRET_KEY | string | `""` | S3 secret key. |
| vault.secrets.VAULT_ADDR | string | `""` | Host of the vault server to backup. |
| vault.secrets.VAULT_EXTRA_ARGS | string | `""` | Vault extra cli args used for backup. |
| vault.secrets.VAULT_TOKEN | string | `""` | Token of the vault server used for backup. |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
