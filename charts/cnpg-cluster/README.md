# cnpg-cluster

![Version: 1.4.0](https://img.shields.io/badge/Version-1.4.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 1.27.1](https://img.shields.io/badge/AppVersion-1.27.1-informational?style=flat-square)

A Helm Chart to deploy easily a CNPG cluster

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| https://cloudnative-pg.github.io/charts | cnpg-operator(cloudnative-pg) | >=0.20.0 |

## Installing the Chart

### CLI

```sh
helm repo add tobi https://this-is-tobi.github.io/helm-charts
helm install <release_name> tobi/cnpg-cluster
```

### ArgoCD

`application.yaml` :

```yaml
[...]
sources:
- repoURL: https://this-is-tobi.github.io/helm-charts
  chart: cnpg-cluster
  targetRevision: 1.4.0
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
- name: cnpg-cluster
  version: 1.4.0
  repository: https://this-is-tobi.github.io/helm-charts
  condition: cnpg-cluster.enabled
```

`values.yaml`:

```yaml
[...]
cnpg-cluster:
  enabled: true
```

## Features

### Database Connection Info Secret

The chart can automatically create a Kubernetes Secret containing all necessary database connection information. This is useful for:
- Application deployments that need database credentials
- Backup tools like `backup-utils`
- Monitoring and maintenance scripts

**Enable the feature:**

```yaml
infosSecret:
  create: true
  secretName: "my-db-connection"  # Optional, defaults to <release-name>-infos
```

**Generated secret contains (keys are configurable):**

| Key | Description | Example | Configurable via |
|-----|-------------|---------|------------------|
| `DB_HOST` | PostgreSQL read-write service hostname | `my-postgres-rw.default.svc` | `infosSecret.keys.host` |
| `DB_PORT` | PostgreSQL port | `5432` | `infosSecret.keys.port` |
| `DB_NAME` | Database name | `myapp` | `infosSecret.keys.name` |
| `DB_USER` | Application username | `myapp_user` | `infosSecret.keys.user` |
| `DB_PASS` | Application password | `generated-password` | `infosSecret.keys.password` |
| `DB_URL` | Full connection string | `postgresql://user:pass@host:5432/db` | `infosSecret.keys.url` |

**Add query parameters to connection URL:**

```yaml
infosSecret:
  create: true
  urlParameters: "sslmode=require&connect_timeout=10&application_name=myapp"
  # Generates: postgresql://user:pass@host:5432/db?sslmode=require&connect_timeout=10&application_name=myapp
```

Common parameters:
- `sslmode` - SSL/TLS mode (`disable`, `require`, `verify-ca`, `verify-full`)
- `connect_timeout` - Connection timeout in seconds
- `application_name` - Application identifier for monitoring
- `options` - PostgreSQL runtime parameters (e.g., `options=-c%20search_path=myschema`)

**Customize environment variable names:**

```yaml
infosSecret:
  create: true
  keys:
    host: "POSTGRES_HOST"      # Instead of DB_HOST
    port: "POSTGRES_PORT"      # Instead of DB_PORT
    name: "POSTGRES_DB"        # Instead of DB_NAME
    user: "POSTGRES_USER"      # Instead of DB_USER
    password: "POSTGRES_PASSWORD"  # Instead of DB_PASS
    connectionString: "DATABASE_URL"  # Instead of DB_URL
```

**Usage example with backup-utils:**

```yaml
# PostgreSQL database
cnpg-cluster:
  enabled: true
  dbName: production
  credentials:
    username: app_user
  infosSecret:
    create: true
    secretName: postgres-connection

# Automated backups
backup-utils:
  enabled: true
  backups:
    postgresBackup:
      enabled: true
      type: postgres
      job:
        schedule: "0 2 * * *"
      envFrom:
        - secretRef:
            name: postgres-connection  # Reference the infos secret
      secrets:
        S3_ENDPOINT: "https://s3.amazonaws.com"
        S3_ACCESS_KEY: "AKIAIOSFODNN7EXAMPLE"
        S3_SECRET_KEY: "secret"
        S3_BUCKET_NAME: "backups"
```

## Values

### Affinity

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{"topologyKey":"topology.kubernetes.io/zone"}` | Affinity rules for the database pods. |
| topologySpreadConstraints | list | `[]` | Topology spread constraints for the database pods. |

### Backup

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| backup.compression | string | `""` | Which compression algorithm should be used for cnpg backups (should be one of "gzip", "bzip2" or "snappy"), leave blank to disable compression. |
| backup.cron | string | `"0 0 */6 * * *"` | The cron rule used for cnpg backups. By default it runs every 6 hours. |
| backup.destinationPath | string | `""` | S3 destination path for cnpg backups (it should be set like `s3://<bucket_name>/<path>`). |
| backup.enabled | bool | `false` | Whether or not cnpg cluster backup should be enabled. |
| backup.endpointCA.create | bool | `false` | Whether or not to create S3 CA kubernetes secret used for cnpg backups. It will use `secretName`, `endpointCA.key` and `endpointCA.value` to create the secret. |
| backup.endpointCA.key | string | `"ca.crt"` | The secret key containing S3 CA for cnpg backups. |
| backup.endpointCA.secretName | string | `""` | The secret name containing S3 CA for cnpg backups, leave it empty to auto-generate the secret name. |
| backup.endpointCA.value | string | `""` | The S3 certificate used for cnpg backups. Only needed if `backup.endpointCA.create` is set to `true`. |
| backup.endpointURL | string | `""` | S3 endpoint for cnpg backups. |
| backup.legacyMode | bool | `true` | Use legacy in-tree backup method instead of barman-cloud plugin (deprecated, will be removed in future CNPG versions). When `false` (recommended), uses the official barman-cloud plugin with ObjectStore CRD. When `true`, falls back to the deprecated in-tree barmanObjectStore configuration. |
| backup.retentionPolicy | string | `"14d"` | Retention policy for cnpg backups recurrences. |
| backup.s3Credentials.accessKeyId.key | string | `"accessKeyId"` | S3 accessKeyId kubernetes secret key used for cnpg backups. |
| backup.s3Credentials.accessKeyId.value | string | `""` | S3 accessKeyId value used for cnpg backups. Only needed if `backup.s3Credentials.create` is set to `true`. |
| backup.s3Credentials.create | bool | `false` | Whether or not to create S3 credentials kubernetes secret used for cnpg backups. It will use `secretName`, `accessKeyId.key`, `accessKeyId.value`, `secretAccessKey.key` and `secretAccessKey.value` to create the secret. |
| backup.s3Credentials.region.key | string | `"region"` | S3 region kubernetes secret key used for cnpg backups. |
| backup.s3Credentials.region.value | string | `"us-east1"` | S3 region value used for cnpg backups. Only needed if `backup.s3Credentials.create` is set to `true`. |
| backup.s3Credentials.secretAccessKey.key | string | `"secretAccessKey"` | S3 secretAccessKey kubernetes secret key used for cnpg backups. |
| backup.s3Credentials.secretAccessKey.value | string | `""` | S3 secretAccessKey value used for cnpg backups. Only needed if `backup.s3Credentials.create` is set to `true`. |
| backup.s3Credentials.secretName | string | `""` | S3 kubernetes secret name used for cnpg backups, leave it empty to auto-generate the secret name. |

### Database

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| credentials.existingSecrets.app.secretName | string | `""` | Name of the kubernetes secret to retrieve app user auth infos. Secret should be of type `kubernetes.io/basic-auth` with `username` and `password` keys. |
| credentials.existingSecrets.enabled | bool | `false` | Enable the load of the following secrets to bootstrap the database, instead of generating them with the previous values. |
| credentials.existingSecrets.postgres.secretName | string | `""` | Name of the kubernetes secret to retrieve postgres superuser auth infos. Secret should be of type `kubernetes.io/basic-auth` with `username` and `password` keys. |
| credentials.password | string | `""` | Password of the database user (leave empty to auto-generate the password). |
| credentials.postgresPassword | string | `""` | Password of the postgres superuser (leave empty to auto-generate the password). |
| credentials.username | string | `""` | Username of the database user (it is used for the database owner - needed also if `credentials.existingSecrets.enabled` is set to `true`). |
| dbName | string | `""` | Name of the database (Default is `fullnameOverride` > `nameOverride` > name of the Helm release). |
| enableSuperuserAccess | bool | `true` | Enable superuser access. |
| exposed | bool | `false` | Whether or not a NodePort service should be created to exposed the database. |
| imageName | string | `""` | Name of the image used for database.  By default (empty string), the operator will install the latest available minor version of the latest major version of PostgreSQL when the operator was released |
| imagePullPolicy | string | `"IfNotPresent"` | Pull policy for the database image. |
| infosSecret.create | bool | `false` | Whether or not to create an infos secret containing database connection information (host, port, database name, username, password, and connection string). This secret can be used by applications or backup tools to connect to the database. |
| infosSecret.keys | object | `{"host":"DB_HOST","name":"DB_NAME","password":"DB_PASS","port":"DB_PORT","url":"DB_URL","user":"DB_USER"}` | Environment variable keys used in the infos secret. Customize these to match your application's requirements. |
| infosSecret.keys.host | string | `"DB_HOST"` | Key for database host. |
| infosSecret.keys.name | string | `"DB_NAME"` | Key for database name. |
| infosSecret.keys.password | string | `"DB_PASS"` | Key for database password. |
| infosSecret.keys.port | string | `"DB_PORT"` | Key for database port. |
| infosSecret.keys.url | string | `"DB_URL"` | Key for database connection string. |
| infosSecret.keys.user | string | `"DB_USER"` | Key for database username. |
| infosSecret.secretName | string | `""` | Name of the secret to create (defaults to `<fullname>-infos`). |
| infosSecret.urlParameters | string | `""` | Query parameters to append to the connection URL (e.g., sslmode, connect_timeout, application_name). Leave empty for no parameters. |
| initDb.extraArgs | object | `{}` | Extra configuration of the initDb bootstrap process (See. https://cloudnative-pg.io/documentation/current/cloudnative-pg.v1/#postgresql-cnpg-io-v1-BootstrapInitDB). |
| instances | int | `3` | Number of instances to spawn in the cluster. |
| mode | string | `"primary"` | Mode used to deploy the cnpg cluster, it should be `primary`, `replica` or `recovery`. |
| nodePort | int | `30000` | Port used for NodePort service. Needs `exposed` tu be true. |
| parameters | object | `{}` | Customize Postgresql parameters. |
| pgHba | list | `[]` | Client authentication entries for pg_hba.conf file (See. https://www.postgresql.org/docs/current/auth-pg-hba-conf.html). |
| primaryUpdateStrategy | string | `"unsupervised"` | Rolling update strategy used. `unsupervised` for automated update of the primary once all replicas have been upgraded (default). `supervised` for manual supervision to perform the switchover of the primary. |

### Image pull secret

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| imageCredentials.email | string | `""` | Email to pull images. |
| imageCredentials.password | string | `""` | Password to pull images. |
| imageCredentials.registry | string | `""` | Registry to pull images from. |
| imageCredentials.username | string | `""` | Username to pull images. |

### Monitoring

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| monitoring.enabled | bool | `false` | Specifies whether the monitoring should be enabled. Requires Prometheus Operator CRDs. |
| monitoring.podMonitor.additionalLabels | object | `{}` | Additional labels for the podMonitor |
| monitoring.podMonitor.extraMatchLabels | object | `{}` | Additional match labels for the podMonitor |
| monitoring.podMonitor.metricRelabelings | list | `[]` | Metrics relabel configurations to apply to samples before ingestion. |
| monitoring.podMonitor.relabelings | list | `[]` | Relabel configurations to apply to samples before scraping. |

### Pooler

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| pooler.enabled | bool | `false` | Whether or not Pgbouncer should be enabled. |
| pooler.instances | int | `3` | The number of replicas we want  |
| pooler.pgbouncer | object | `{}` | The PgBouncer configuration (see. https://www.pgbouncer.org/config.html). |
| pooler.template | object | `{}` | The template of the Pod to be created (see. https://cloudnative-pg.io/documentation/current/connection_pooling/#pod-templates). |
| pooler.type | string | `"rw"` | Which instances we must forward traffic to. |

### Resources

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| pvcSize.data | string | `"2Gi"` | Size of the data PVC used by each cnpg instance. |
| pvcSize.wal | string | `"1Gi"` | Size of the WAL PVC used by each cnpg instance (if value is `null` then WAL files are stored within the data PVC). |
| resources.limits.cpu | string | `"500m"` | CPU limit for the database instance. |
| resources.limits.memory | string | `"1Gi"` | Memory limit for the database instance. |
| resources.requests.cpu | string | `"250m"` | CPU request for the database instance. |
| resources.requests.memory | string | `"512Mi"` | Memory request for the database instance. |
| storageClass | string | `""` | Storage class used for data and WAL PVCs. Leave empty to use the default storage class of the cluster. |

### Recovery mode

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| recovery.clusterName | string | `""` | Primary cnpg cluster name used for recovery mode. |
| recovery.destinationPath | string | `""` | S3 destination path used for recovery mode (it should be set like `s3://<bucket_name>/<path>`). |
| recovery.endpointCA.create | bool | `false` | Whether or not to create S3 CA kubernetes secret used for recovery mode. It will use `secretName`, `endpointCA.key` and `endpointCA.value` to create the secret. |
| recovery.endpointCA.key | string | `"ca.crt"` | The secret key containing S3 CA used for recovery mode. |
| recovery.endpointCA.secretName | string | `""` | The secret name containing S3 CA used for recovery mode, leave it empty to auto-generate the secret name. |
| recovery.endpointCA.value | string | `""` | The S3 certificate used for recovery mode. Only needed if `recovery.endpointCA.create` is set to `true`. |
| recovery.endpointURL | string | `""` | S3 endpoint used for recovery mode. |
| recovery.extraArgs | object | `{}` | Extra configuration of the initDb bootstrap process (See. https://cloudnative-pg.io/documentation/current/cloudnative-pg.v1/#postgresql-cnpg-io-v1-BootstrapInitDB). |
| recovery.maxParallelWal | int | `8` | The number of parallel process that will be applied when applying wals. |
| recovery.s3Credentials.accessKeyId.key | string | `"accessKeyId"` | S3 accessKeyId kubernetes secret key used for recovery mode. |
| recovery.s3Credentials.accessKeyId.value | string | `""` | S3 accessKeyId value used for recovery mode. Only needed if `recovery.s3Credentials.create` is set to `true`. |
| recovery.s3Credentials.create | bool | `false` | Whether or not to create S3 credentials kubernetes secret used for recovery mode. It will use `secretName`, `accessKeyId.key`, `accessKeyId.value`, `secretAccessKey.key` and `secretAccessKey.value` to create the secret. |
| recovery.s3Credentials.region.key | string | `"region"` | S3 region kubernetes secret key used for recovery mode. |
| recovery.s3Credentials.region.value | string | `"us-east1"` | S3 region value used for recovery mode. Only needed if `recovery.s3Credentials.create` is set to `true`. |
| recovery.s3Credentials.secretAccessKey.key | string | `"secretAccessKey"` | S3 secretAccessKey kubernetes secret key used for recovery mode. |
| recovery.s3Credentials.secretAccessKey.value | string | `""` | S3 secretAccessKey value used for recovery mode. Only needed if `recovery.s3Credentials.create` is set to `true`. |
| recovery.s3Credentials.secretName | string | `""` | S3 kubernetes secret name used for recovery mode, leave it empty to auto-generate the secret name. |

### Replica mode

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| replica.clusterName | string | `""` | Primary cnpg cluster name used for replica mode. |
| replica.dbName | string | `""` | Primary database name used for replica mode. |
| replica.destinationPath | string | `""` | S3 destination path used for replica mode (it should be set like `s3://<bucket_name>/<path>`). |
| replica.endpointCA.create | bool | `false` | Whether or not to create S3 CA kubernetes secret used for replica mode. It will use `secretName`, `endpointCA.key` and `endpointCA.value` to create the secret. |
| replica.endpointCA.key | string | `"ca.crt"` | The secret key containing S3 CA used for replica mode. |
| replica.endpointCA.secretName | string | `""` | The secret name containing S3 CA used for replica mode, leave it empty to auto-generate the secret name. |
| replica.endpointCA.value | string | `""` | The S3 certificate used for replica mode. Only needed if `replica.endpointCA.create` is set to `true`. |
| replica.endpointURL | string | `""` | S3 endpoint used for replica mode. |
| replica.extraArgs | object | `{}` | Extra configuration of the initDb bootstrap process (See. https://cloudnative-pg.io/documentation/current/cloudnative-pg.v1/#postgresql-cnpg-io-v1-BootstrapInitDB). |
| replica.host | string | `""` | Primary cnpg cluster host used for replica mode. |
| replica.maxParallelWal | int | `8` | The number of parallel process that will be applied when applying wals. |
| replica.port | int | `5432` | Primary cnpg cluster port used for replica mode. |
| replica.s3Credentials.accessKeyId.key | string | `"accessKeyId"` | S3 accessKeyId kubernetes secret key used for replica mode. |
| replica.s3Credentials.accessKeyId.value | string | `""` | S3 accessKeyId value used for replica mode. Only needed if `replica.s3Credentials.create` is set to `true`. |
| replica.s3Credentials.create | bool | `false` | Whether or not to create S3 credentials kubernetes secret used for replica mode. It will use `secretName`, `accessKeyId.key`, `accessKeyId.value`, `secretAccessKey.key` and `secretAccessKey.value` to create the secret. |
| replica.s3Credentials.region.key | string | `"region"` | S3 region kubernetes secret key used for replica mode. |
| replica.s3Credentials.region.value | string | `"us-east1"` | S3 region value used for replica mode. Only needed if `replica.s3Credentials.create` is set to `true`. |
| replica.s3Credentials.secretAccessKey.key | string | `"secretAccessKey"` | S3 secretAccessKey kubernetes secret key used for replica mode. |
| replica.s3Credentials.secretAccessKey.value | string | `""` | S3 secretAccessKey value used for replica mode. Only needed if `replica.s3Credentials.create` is set to `true`. |
| replica.s3Credentials.secretName | string | `""` | S3 kubernetes secret name used for replica mode, leave it empty to auto-generate the secret name. |
| replica.sslMode | string | `"prefer"` | SSL connection config used for replica mode. |

### Other Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| annotations | object | `{}` | Additional annotations for created resources. |
| cnpg-operator.enabled | bool | `false` | Whether or not cnpg operator should be deployed (See. https://artifacthub.io/packages/helm/cloudnative-pg/cloudnative-pg?modal=values). |
| fullnameOverride | string | `""` | String to fully override the default application name. |
| labels | object | `{}` | Additional cnpg cluster labels. |
| logLevel | string | `"info"` | Log level used by the operator (one of `error`, `warning`, `info` (default), `debug`, `trace`). |
| nameOverride | string | `""` | Provide a name in place of the default application name. |

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| this-is-tobi | <this-is-tobi@proton.me> | <https://this-is-tobi.com> |

## Sources

**Homepage:** <https://cloudnative-pg.io>

**Source code:**

* <https://github.com/this-is-tobi/helm-charts>
* <https://artifacthub.io/packages/helm/cloudnative-pg/cloudnative-pg>

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
