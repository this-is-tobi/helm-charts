# backup-utils

![Version: 2.0.0](https://img.shields.io/badge/Version-2.0.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 1.0.0](https://img.shields.io/badge/AppVersion-1.0.0-informational?style=flat-square)

A Helm chart for effortless deployment of backup utilities (postgresql, s3, vault, and qdrant).

## Overview

This Helm chart deploys scheduled backup jobs for various data sources (PostgreSQL, Vault, S3, Qdrant) to S3-compatible storage using rclone. Each backup job runs as a Kubernetes CronJob with configurable schedules and retention policies.

### Supported Backup Types

| Type | Description | Required Environment Variables |
|------|-------------|-------------------------------|
| **postgres** | PostgreSQL database dumps | `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASS` |
| **vault** | HashiCorp Vault snapshots | `VAULT_ADDR`, `VAULT_TOKEN` |
| **s3** | S3-to-S3 bucket sync | `SOURCE_S3_ENDPOINT`, `SOURCE_S3_ACCESS_KEY`, `SOURCE_S3_SECRET_KEY`, `SOURCE_S3_BUCKET_NAME` |
| **qdrant** | Qdrant vector database snapshots | `QDRANT_URL`, `QDRANT_API_KEY` (optional: `QDRANT_COLLECTION`) |

All backup types require S3 destination configuration: `S3_ENDPOINT`, `S3_ACCESS_KEY`, `S3_SECRET_KEY`, `S3_BUCKET_NAME`.

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

## Configuration Structure

### Backups Map

The chart uses a `backups` map where each key represents a unique backup job. Each backup job will create its own CronJob, ConfigMap, and Secret resources.

**Key Features:**
- **Map Keys**: Each key in the `backups` map becomes a backup job identifier (e.g., `postgres-prod`, `vault-backup`)
- **Naming**: Backup names are automatically converted to kebab-case for Kubernetes compliance (e.g., `myBackup` → `my-backup`)
- **Resources**: Each backup creates:
  - 1 CronJob named `<release-name>-<backup-key>`
  - 1 ConfigMap (if `env` or `global.env` is defined)
  - 1 Secret (if `secrets` or `global.secrets` is defined)
- **Independent Configuration**: Each backup can have its own schedule, type, environment variables, and resources
- **Global Values**: Use `global.env` and `global.secrets` to define common configuration shared across all backups (e.g., S3 credentials)

**Example Structure:**

```yaml
global:
  env:
    S3_PATH_STYLE: "true"
  secrets:
    S3_ENDPOINT: "https://s3.amazonaws.com"
    S3_ACCESS_KEY: "shared-key"
    S3_SECRET_KEY: "shared-secret"
    S3_BUCKET_NAME: "backups"

backups:
  first-backup:      # Creates: release-name-first-backup
    enabled: true
    type: postgres
    # ... configuration ...
 
  second-backup:     # Creates: release-name-second-backup
    enabled: true
    type: vault
    # ... configuration ...
```

## Usage Examples

### Example 1: PostgreSQL Backup

```yaml
backups:
  postgres-prod:
    enabled: true
    type: postgres
    job:
      schedule: "0 2 * * *"  # Daily at 2 AM
    env:
      RETENTION: "30d"
    secrets:
      # PostgreSQL connection
      DB_HOST: "postgres.default.svc.cluster.local"
      DB_PORT: "5432"
      DB_NAME: "myapp"
      DB_USER: "backup_user"
      DB_PASS: "secure_password"
      # S3 destination
      S3_ENDPOINT: "https://s3.amazonaws.com"
      S3_ACCESS_KEY: "AKIAIOSFODNN7EXAMPLE"
      S3_SECRET_KEY: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
      S3_BUCKET_NAME: "my-backups"
      S3_BUCKET_PREFIX: "postgres/prod/"
```

### Example 2: Qdrant Vector Database Backup

```yaml
backups:
  qdrant-prod:
    enabled: true
    type: qdrant
    job:
      schedule: "0 3 * * *"  # Daily at 3 AM
    env:
      RETENTION: "14d"
    secrets:
      # Qdrant connection
      QDRANT_URL: "https://qdrant.default.svc.cluster.local:6333"
      QDRANT_API_KEY: "your-api-key"
      QDRANT_COLLECTION: "my-collection"  # Leave empty to backup all collections
      # S3 destination
      S3_ENDPOINT: "https://s3.amazonaws.com"
      S3_ACCESS_KEY: "AKIAIOSFODNN7EXAMPLE"
      S3_SECRET_KEY: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
      S3_BUCKET_NAME: "my-backups"
      S3_BUCKET_PREFIX: "qdrant/prod/"
```

### Example 3: Multiple Backup Jobs

```yaml
backups:
  postgres-prod:
    enabled: true
    type: postgres
    job:
      schedule: "0 2 * * *"
    secrets:
      DB_HOST: "postgres.prod.svc.cluster.local"
      # ... other postgres config
      S3_BUCKET_PREFIX: "postgres/prod/"
 
  qdrant-prod:
    enabled: true
    type: qdrant
    job:
      schedule: "0 3 * * *"
    secrets:
      QDRANT_URL: "https://qdrant.default.svc.cluster.local:6333"
      QDRANT_API_KEY: "your-api-key"
      # ... S3 config
      S3_BUCKET_PREFIX: "qdrant/"
 
  vault-backup:
    enabled: true
    type: vault
    job:
      schedule: "0 4 * * *"
    secrets:
      VAULT_ADDR: "https://vault.default.svc.cluster.local:8200"
      VAULT_TOKEN: "hvs.xxx"
      # ... S3 config
      S3_BUCKET_PREFIX: "vault/"
```

### Example 4: Using Global Configuration

Share common S3 credentials across all backups:

```yaml
global:
  secrets:
    S3_ENDPOINT: "https://s3.amazonaws.com"
    S3_ACCESS_KEY: "AKIAIOSFODNN7EXAMPLE"
    S3_SECRET_KEY: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
    S3_BUCKET_NAME: "my-backups"

backups:
  postgres-prod:
    enabled: true
    type: postgres
    secrets:
      DB_HOST: "postgres"
      DB_PORT: "5432"
      DB_NAME: "myapp"
      DB_USER: "backup_user"
      DB_PASS: "password"
      S3_BUCKET_PREFIX: "postgres/"  # Only specify unique values
```

## Configuration Notes

### Retention Policy
- Uses rclone duration format: `7d`, `168h`, `10080m`, `2w`
- Older backups are automatically deleted based on this setting
- Consider backup size and storage costs when setting retention

### Cron Schedule
- Uses standard cron format: `minute hour day month weekday`
- Examples:
  - `"0 2 * * *"` - Daily at 2 AM
  - `"0 */6 * * *"` - Every 6 hours
  - `"0 2 * * 0"` - Weekly on Sunday at 2 AM

### Resource Allocation
- Default: 128Mi memory request, 512Mi limit
- Increase for large databases (e.g., 1Gi/2Gi for multi-GB dumps)
- Monitor actual usage and adjust accordingly

### Security Best Practices
- Use Kubernetes Secrets for sensitive values (recommended)
- Enable `podSecurityContext` for non-root execution
- Consider network policies to restrict backup pod access
- Rotate S3 credentials regularly

## Values

### Backups

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| backups.myBackup.container.args | list | `[]` | Override default container arguments. Leave empty to use image default (recommended). |
| backups.myBackup.container.command | list | `[]` | Override default container command. Leave empty to use image default (recommended). |
| backups.myBackup.container.port | int | `8080` | Container port (used for health checks or communication, typically 8080). |
| backups.myBackup.container.securityContext | object | `{}` | Container security context (capabilities, read-only filesystem, user/group IDs). |
| backups.myBackup.enabled | bool | `true` | Enable or disable this specific backup job. |
| backups.myBackup.envFrom | list | `[]` | Additional environment variables from existing ConfigMaps or Secrets. |
| backups.myBackup.image.pullPolicy | string | `"IfNotPresent"` | Image pull policy. Options: `Always`, `IfNotPresent`, `Never`. |
| backups.myBackup.image.repository | string | `"ghcr.io/this-is-tobi/tools/backup"` | Container image repository containing the backup scripts. |
| backups.myBackup.image.tag | string | `"0.1.0"` | Container image tag (version). Defaults to chart appVersion if not specified. |
| backups.myBackup.job.backoffLimit | int | `3` | Maximum number of retry attempts before marking the job as failed. |
| backups.myBackup.job.concurrencyPolicy | string | `"Forbid"` | How to handle overlapping job runs. Options: `Forbid` (skip if running), `Allow` (run in parallel), `Replace` (kill and restart). |
| backups.myBackup.job.failedJobsHistoryLimit | int | `3` | Number of failed job executions to keep in history (for troubleshooting). |
| backups.myBackup.job.schedule | string | `"0 0 * * *"` | Cron schedule expression (e.g., "0 0 * * *" = daily at midnight UTC). |
| backups.myBackup.job.successfulJobsHistoryLimit | int | `3` | Number of successful job executions to keep in history (for troubleshooting). |
| backups.myBackup.job.timeZone | string | `""` | IANA timezone for schedule (e.g., "Europe/Paris", "America/New_York"). Empty = UTC. |
| backups.myBackup.jobAnnotations | object | `{}` | Custom annotations added to the CronJob resource (optional). |
| backups.myBackup.jobLabels | object | `{}` | Custom labels added to the CronJob resource (optional). |
| backups.myBackup.podAnnotations | object | `{}` | Custom annotations added to the backup pod (optional). |
| backups.myBackup.podLabels | object | `{}` | Custom labels added to the backup pod (optional). |
| backups.myBackup.podSecurityContext | object | `{}` | Pod security context settings (user/group IDs, fsGroup, etc.). |
| backups.myBackup.resources.limits.cpu | string | `"250m"` | Maximum CPU allowed for the backup container (throttled if exceeded). |
| backups.myBackup.resources.limits.memory | string | `"512Mi"` | Maximum memory allowed for the backup container. Container will be killed if exceeded. |
| backups.myBackup.resources.requests.cpu | string | `"100m"` | Minimum CPU guaranteed for the backup container (1000m = 1 CPU core). |
| backups.myBackup.resources.requests.memory | string | `"128Mi"` | Minimum memory guaranteed for the backup container. Adjust based on backup size. |
| backups.myBackup.restartPolicy | string | `"Never"` | Pod restart policy. Options: `Never` (recommended), `OnFailure`, `Always`. |
| backups.myBackup.type | string | `"postgres"` | Backup type determining which script to run. Valid values: `postgres`, `s3`, `qdrant`, `vault`. |

### Config - Common

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| backups.myBackup.env.RCLONE_EXTRA_ARGS | string | `""` | Additional rclone CLI arguments (e.g., "--transfers=4" or "--checkers=8" for performance tuning). |
| backups.myBackup.env.RETENTION | string | `"7d"` | Backup retention period in rclone duration format. Examples: "7d" (7 days), "168h" (1 week), "2w" (2 weeks). |
| backups.myBackup.env.S3_PATH_STYLE | string | `"true"` | Use S3 path-style URLs. Set to "true" for most providers. Set to "false" if bucket is in endpoint (e.g., "https://bucket.s3.amazonaws.com"). |
| backups.myBackup.secrets.S3_ACCESS_KEY | string | `""` | S3 access key ID for authentication. |
| backups.myBackup.secrets.S3_BUCKET_NAME | string | `""` | S3 bucket name where backups will be stored. |
| backups.myBackup.secrets.S3_BUCKET_PREFIX | string | `""` | S3 bucket path prefix (folder path within bucket, e.g., "prod/postgres" or "backups/"). |
| backups.myBackup.secrets.S3_ENDPOINT | string | `""` | S3 endpoint URL (e.g., "https://s3.amazonaws.com", "https://minio.example.com:9000"). |
| backups.myBackup.secrets.S3_SECRET_KEY | string | `""` | S3 secret access key for authentication. |

### Config - Postgres

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| backups.myBackup.secrets.DB_HOST | string | `""` | PostgreSQL server hostname or IP address (e.g., "postgres.default.svc.cluster.local"). |
| backups.myBackup.secrets.DB_NAME | string | `""` | PostgreSQL database name to backup. |
| backups.myBackup.secrets.DB_PASS | string | `""` | PostgreSQL user password. |
| backups.myBackup.secrets.DB_PORT | string | `""` | PostgreSQL server port (default: "5432"). |
| backups.myBackup.secrets.DB_USER | string | `""` | PostgreSQL username with backup/read permissions. |

### Config - Qdrant

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| backups.myBackup.secrets.QDRANT_API_KEY | string | `""` | Qdrant API key for authentication. |
| backups.myBackup.secrets.QDRANT_COLLECTION | string | `""` | Qdrant collection name to backup (leave empty to backup all collections). |
| backups.myBackup.secrets.QDRANT_URL | string | `""` | Qdrant server URL (e.g., "https://qdrant.example.com"). |

### Config - S3

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| backups.myBackup.secrets.SOURCE_S3_ACCESS_KEY | string | `""` | Source S3 access key ID for authentication. |
| backups.myBackup.secrets.SOURCE_S3_BUCKET_NAME | string | `""` | Source S3 bucket name to backup from. |
| backups.myBackup.secrets.SOURCE_S3_BUCKET_PREFIX | string | `""` | Source S3 bucket path prefix to backup (e.g., "data/" to backup only specific folder). |
| backups.myBackup.secrets.SOURCE_S3_ENDPOINT | string | `""` | Source S3 endpoint URL to backup from (e.g., "https://s3.us-west-2.amazonaws.com"). |
| backups.myBackup.secrets.SOURCE_S3_SECRET_KEY | string | `""` | Source S3 secret access key for authentication. |

### Config - Vault

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| backups.myBackup.secrets.VAULT_ADDR | string | `""` | Vault server address (e.g., "https://vault.example.com:8200"). |
| backups.myBackup.secrets.VAULT_EXTRA_ARGS | string | `""` | Additional Vault CLI arguments (e.g., "-namespace=admin" for enterprise features). |
| backups.myBackup.secrets.VAULT_TOKEN | string | `""` | Vault authentication token with backup/snapshot permissions. |

### Global

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| global.env | object | `{}` | Environment variables (non-sensitive) injected into all backup containers. |
| global.secrets | object | `{}` | Secret environment variables (sensitive) injected into all backup containers. |

### Image pull secret

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| imageCredentials.email | string | `""` | Email address associated with the registry account. |
| imageCredentials.password | string | `""` | Registry password for authentication. |
| imageCredentials.registry | string | `""` | Container registry URL (e.g., "docker.io", "ghcr.io"). |
| imageCredentials.username | string | `""` | Registry username for authentication. |

### Other Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| fullnameOverride | string | `""` | Override the full resource name (release-name + chart-name). |
| nameOverride | string | `""` | Override the chart name (used in resource naming). |

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
