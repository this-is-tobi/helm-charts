# cnpg-cluster

![Version: 0.9.1](https://img.shields.io/badge/Version-0.9.1-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 1.25.0](https://img.shields.io/badge/AppVersion-1.25.0-informational?style=flat-square)

A Helm Chart to deploy easily a CNPG cluster

**Homepage:** <https://cloudnative-pg.io>

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| this-is-tobi | <this-is-tobi@proton.me> | <https://this-is-tobi.com> |

## Source Code

* <https://github.com/this-is-tobi/helm-charts>
* <https://artifacthub.io/packages/helm/cloudnative-pg/cloudnative-pg>

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| https://cloudnative-pg.github.io/charts | cnpg-operator(cloudnative-pg) | 0.23.0 |

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| annotations | object | `{}` | Additional annotations for created resources. |
| backup.compression | string | `""` | Which compression algorithm should be used for cnpg backups (should be one of "gzip", "bzip2" or "snappy"), leave blank to disable compression. |
| backup.cron | string | `"0 0 */6 * * *"` | The cron rule used for cnpg backups. By default it runs every 6 hours. |
| backup.destinationPath | string | `""` | S3 destination path for cnpg backups (it should be set like `s3://<bucket_name>/<path>`). |
| backup.enabled | bool | `false` | Whether or not cnpg cluster deployment should be enabled. |
| backup.endpointCA.create | bool | `false` | Whether or not to create S3 CA kubernetes secret used for cnpg backups. It will use `secretName`, `endpointCA.key` and `endpointCA.value` to create the secret. |
| backup.endpointCA.key | string | `"ca.crt"` | The secret key containing S3 CA for cnpg backups. |
| backup.endpointCA.secretName | string | `""` | The secret name containing S3 CA for cnpg backups, leave it empty to auto-generate the secret name. |
| backup.endpointCA.value | string | `""` | The S3 certificate used for cnpg backups. Only needed if `backup.endpointCA.create` is set to `true`. |
| backup.endpointURL | string | `""` | S3 endpoint for cnpg backups. |
| backup.retentionPolicy | string | `"14d"` | Retention policy for cnpg backups recurrences. |
| backup.s3Credentials.accessKeyId.key | string | `"accessKeyId"` | S3 accessKeyId kubernetes secret key used for cnpg backups. |
| backup.s3Credentials.accessKeyId.value | string | `""` | S3 accessKeyId value used for cnpg backups. Only needed if `backup.s3Credentials.create` is set to `true`. |
| backup.s3Credentials.create | bool | `false` | Whether or not to create S3 credentials kubernetes secret used for cnpg backups. It will use `secretName`, `accessKeyId.key`, `accessKeyId.value`, `secretAccessKey.key` and `secretAccessKey.value` to create the secret. |
| backup.s3Credentials.region.key | string | `"region"` | S3 region kubernetes secret key used used for cnpg backups. |
| backup.s3Credentials.region.value | string | `"us-east1"` | S3 region value used used for cnpg backups. Only needed if `backup.s3Credentials.create` is set to `true`. |
| backup.s3Credentials.secretAccessKey.key | string | `"secretAccessKey"` | S3 secretAccessKey kubernetes secret key used for cnpg backups. |
| backup.s3Credentials.secretAccessKey.value | string | `""` | S3 secretAccessKey value used for cnpg backups. Only needed if `backup.s3Credentials.create` is set to `true`. |
| backup.s3Credentials.secretName | string | `""` | S3 kubernetes secret name used for cnpg backups, leave it empty to auto-generate the secret name. |
| cnpg-operator.enabled | bool | `false` | Whether or not cnpg operator should be deployed (See. https://artifacthub.io/packages/helm/cloudnative-pg/cloudnative-pg?modal=values). |
| credentials.existingSecrets.app.secretName | string | `""` | Name of the kubernetes secret to retrieve app user auth infos. Secret should be of type `kubernetes.io/basic-auth` with `username` and `password` keys. |
| credentials.existingSecrets.enabled | bool | `false` | Enable the load of the following secrets to bootstrap the database, instead of generating them with the previous values. |
| credentials.existingSecrets.postgres.secretName | string | `""` | Name of the kubernetes secret to retrieve postgres superuser auth infos. Secret should be of type `kubernetes.io/basic-auth` with `username` and `password` keys. |
| credentials.password | string | `""` | Password of the database user (leave empty to auto-generate the password). |
| credentials.postgresPassword | string | `""` | Password of the postgres superuser (leave empty to auto-generate the password). |
| credentials.username | string | `""` | Username of the database user (Default is `fullnameOverride` > `nameOverride` > name of the Helm release). |
| dbName | string | `""` | Name of the database (Default is `fullnameOverride` > `nameOverride` > name of the Helm release). |
| enableSuperuserAccess | bool | `true` | Enable superuser access. |
| exposed | bool | `false` | Whether or not a NodePort service should be created to exposed the database. |
| fullnameOverride | string | `""` | String to fully override the default application name. |
| imageCredentials.email | string | `""` | Email to pull images. |
| imageCredentials.password | string | `""` | Password to pull images. |
| imageCredentials.registry | string | `""` | Registry to pull images from. |
| imageCredentials.username | string | `""` | Username to pull images. |
| imageName | string | `""` | Name of the image used for database.  By default (empty string), the operator will install the latest available minor version of the latest major version of PostgreSQL when the operator was released |
| initDb.extraArgs | object | `{}` | Extra configuration of the initDb bootstrap process (See. https://cloudnative-pg.io/documentation/current/cloudnative-pg.v1/#postgresql-cnpg-io-v1-BootstrapInitDB). |
| instances | int | `3` | Number of instances to spawn in the cluster. |
| labels | object | `{}` | Additional cnpg cluster labels. |
| mode | string | `"primary"` | Mode used to deploy the cnpg cluster, it should be `primary`, `replica` or `recovery`. |
| nameOverride | string | `""` | Provide a name in place of the default application name. |
| nodePort | string | `nil` | Port used for NodePort service. Needs `exposed` tu be true. |
| parameters | object | `{}` | Customize Postgresql parameters. |
| pgHba | list | `[]` | Client authentication entries for pg_hba.conf file (See. https://www.postgresql.org/docs/current/auth-pg-hba-conf.html). |
| primaryUpdateStrategy | string | `"unsupervised"` | Rolling update strategy used : unsupervised: automated update of the primary once all replicas have been upgraded (default) supervised: requires manual supervision to perform the switchover of the primary |
| pvcSize.data | string | `"10Gi"` | Size of the data PVC used by each cnpg instance. |
| pvcSize.wal | string | `"5Gi"` | Size of the WAL PVC used by each cnpg instance (if value is `null` then WAL files are stored within the data PVC). |
| recovery.clusterName | string | `""` | Primary cnpg cluster name used for recovery mode. |
| recovery.destinationPath | string | `""` | S3 destination path used for recovery mode (it should be set like `s3://<bucket_name>/<path>`). |
| recovery.endpointCA.create | bool | `false` | Whether or not to create S3 CA kubernetes secret used used for recovery mode. It will use `secretName`, `endpointCA.key` and `endpointCA.value` to create the secret. |
| recovery.endpointCA.key | string | `"ca.crt"` | The secret key containing S3 CA used for recovery mode. |
| recovery.endpointCA.secretName | string | `""` | The secret name containing S3 CA used for recovery mode, leave it empty to auto-generate the secret name. |
| recovery.endpointCA.value | string | `""` | The S3 certificate used used for recovery mode. Only needed if `recovery.endpointCA.create` is set to `true`. |
| recovery.endpointURL | string | `""` | S3 endpoint used for recovery mode. |
| recovery.extraArgs | object | `{}` |  |
| recovery.maxParallelWal | int | `8` | The number of parallel process that will be applied when applying wals. |
| recovery.s3Credentials.accessKeyId.key | string | `"accessKeyId"` | S3 accessKeyId kubernetes secret key used used for recovery mode. |
| recovery.s3Credentials.accessKeyId.value | string | `""` | S3 accessKeyId value used used for recovery mode. Only needed if `recovery.s3Credentials.create` is set to `true`. |
| recovery.s3Credentials.create | bool | `false` | Whether or not to create S3 credentials kubernetes secret used used for recovery mode. It will use `secretName`, `accessKeyId.key`, `accessKeyId.value`, `secretAccessKey.key` and `secretAccessKey.value` to create the secret. |
| recovery.s3Credentials.region.key | string | `"region"` | S3 region kubernetes secret key used used for recovery mode. |
| recovery.s3Credentials.region.value | string | `"us-east1"` | S3 region value used used for recovery mode. Only needed if `recovery.s3Credentials.create` is set to `true`. |
| recovery.s3Credentials.secretAccessKey.key | string | `"secretAccessKey"` | S3 secretAccessKey kubernetes secret key used used for recovery mode. |
| recovery.s3Credentials.secretAccessKey.value | string | `""` | S3 secretAccessKey value used used for recovery mode. Only needed if `recovery.s3Credentials.create` is set to `true`. |
| recovery.s3Credentials.secretName | string | `""` | S3 kubernetes secret name used used for recovery mode, leave it empty to auto-generate the secret name. |
| replica.clusterName | string | `""` | Primary cnpg cluster name used for replica mode. |
| replica.dbName | string | `""` | Primary database name used for replica mode. |
| replica.destinationPath | string | `""` | S3 destination path used for replica mode (it should be set like `s3://<bucket_name>/<path>`). |
| replica.endpointCA.create | bool | `false` | Whether or not to create S3 CA kubernetes secret used used for replica mode. It will use `secretName`, `endpointCA.key` and `endpointCA.value` to create the secret. |
| replica.endpointCA.key | string | `"ca.crt"` | The secret key containing S3 CA used for replica mode. |
| replica.endpointCA.secretName | string | `""` | The secret name containing S3 CA used for replica mode, leave it empty to auto-generate the secret name. |
| replica.endpointCA.value | string | `""` | The S3 certificate used used for replica mode. Only needed if `replica.endpointCA.create` is set to `true`. |
| replica.endpointURL | string | `""` | S3 endpoint used for replica mode. |
| replica.extraArgs | object | `{}` |  |
| replica.host | string | `""` | Primary cnpg cluster host used for replica mode. |
| replica.maxParallelWal | int | `8` | The number of parallel process that will be applied when applying wals. |
| replica.port | int | `5432` | Primary cnpg cluster port used for replica mode. |
| replica.s3Credentials.accessKeyId.key | string | `"accessKeyId"` | S3 accessKeyId kubernetes secret key used used for replica mode. |
| replica.s3Credentials.accessKeyId.value | string | `""` | S3 accessKeyId value used used for replica mode. Only needed if `replica.s3Credentials.create` is set to `true`. |
| replica.s3Credentials.create | bool | `false` | Whether or not to create S3 credentials kubernetes secret used used for replica mode. It will use `secretName`, `accessKeyId.key`, `accessKeyId.value`, `secretAccessKey.key` and `secretAccessKey.value` to create the secret. |
| replica.s3Credentials.region.key | string | `"region"` | S3 region kubernetes secret key used used for replica mode. |
| replica.s3Credentials.region.value | string | `"us-east1"` | S3 region value used used for replica mode. Only needed if `replica.s3Credentials.create` is set to `true`. |
| replica.s3Credentials.secretAccessKey.key | string | `"secretAccessKey"` | S3 secretAccessKey kubernetes secret key used used for replica mode. |
| replica.s3Credentials.secretAccessKey.value | string | `""` | S3 secretAccessKey value used used for replica mode. Only needed if `replica.s3Credentials.create` is set to `true`. |
| replica.s3Credentials.secretName | string | `""` | S3 kubernetes secret name used used for replica mode, leave it empty to auto-generate the secret name. |
| replica.sslMode | string | `"prefer"` | SSL connection config used for replica mode. |
| resources.limits.cpu | string | `"500m"` | CPU limit for the database instance. |
| resources.limits.memory | string | `"1Gi"` | Memory limit for the database instance. |
| resources.requests.cpu | string | `"250m"` | CPU request for the database instance. |
| resources.requests.memory | string | `"512Mi"` | Memory request for the database instance. |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
