# backup-utils

![Version: 2.3.4](https://img.shields.io/badge/Version-2.3.4-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 1.1.3](https://img.shields.io/badge/AppVersion-1.1.3-informational?style=flat-square)

Production-ready Helm chart for automated backups of PostgreSQL, MariaDB, Vault, Qdrant, and S3 buckets to S3-compatible storage with configurable schedules and retention policies.

## Overview

This Helm chart provides a **production-ready solution** for deploying automated backup jobs to S3-compatible storage. It supports multiple data sources and creates dedicated Kubernetes CronJobs with configurable schedules, retention policies, and resource limits.

### Key Features

- **Automated Backups**: Schedule backups using cron expressions
- **Multiple Data Sources**: PostgreSQL, Vault, Qdrant, S3-to-S3
- **S3-Compatible Storage**: Works with AWS S3, MinIO, Wasabi, etc.
- **Secure**: Credentials stored in Kubernetes Secrets
- **Resource Efficient**: Configurable CPU/memory limits per job
- **Retention Management**: Automatic cleanup of old backups
- **Global Configuration**: Share common settings across multiple backups

### Supported Backup Types

| Type | Description | Required Environment Variables |
|------|-------------|-------------------------------|
| **postgres** | PostgreSQL database dumps using `pg_dump` | `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASS` |
| **mariadb** | MariaDB/MySQL database dumps using `mariadb-dump` | `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASS` |
| **vault** | HashiCorp Vault snapshots (raft storage) | `VAULT_ADDR`, `VAULT_TOKEN` |
| **s3** | S3-to-S3 bucket synchronization | `SOURCE_S3_ENDPOINT`, `SOURCE_S3_ACCESS_KEY`, `SOURCE_S3_SECRET_KEY`, `SOURCE_S3_BUCKET_NAME` |
| **qdrant** | Qdrant vector database snapshots | `QDRANT_URL`, `QDRANT_API_KEY`, `QDRANT_COLLECTION` (optional) |

**Common Requirements**: All types require S3 destination configuration: `S3_ENDPOINT`, `S3_ACCESS_KEY`, `S3_SECRET_KEY`, `S3_BUCKET_NAME`.

## Installing the Chart

### Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- S3-compatible storage (AWS S3, MinIO, etc.)
- Access credentials for data sources to backup

### CLI

**Using Traditional Helm Repository:**
```sh
helm repo add tobi https://this-is-tobi.github.io/helm-charts
helm repo update
helm install <release_name> tobi/backup-utils
```

**Using OCI Registry (Recommended):**
```sh
helm install <release_name> oci://ghcr.io/this-is-tobi/helm-charts/backup-utils --version 2.3.4
```

### ArgoCD

**Using Traditional Helm Repository:**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: backup-utils
spec:
  project: default
  sources:
  - repoURL: https://this-is-tobi.github.io/helm-charts
    chart: backup-utils
    targetRevision: 2.3.4
    helm:
      releaseName: <release_name>
      values: |
        backups:
          postgres-prod:
            enabled: true
            type: postgres
            job:
              schedule: "0 2 * * *"
            secrets:
              DB_HOST: "postgres.default.svc"
              # ... other config
  destination:
    server: https://kubernetes.default.svc
    namespace: default
```

**Using OCI Registry (Recommended):**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: backup-utils
spec:
  project: default
  sources:
  - repoURL: ghcr.io/this-is-tobi/helm-charts
    chart: backup-utils
    targetRevision: 2.3.4
    helm:
      releaseName: <release_name>
      values: |
        backups:
          postgres-prod:
            enabled: true
            type: postgres
            job:
              schedule: "0 2 * * *"
            secrets:
              DB_HOST: "postgres.default.svc"
              # ... other config
  destination:
    server: https://kubernetes.default.svc
    namespace: default
```

### Helm Dependency

**Using Traditional Helm Repository:**
```yaml
# Chart.yaml
dependencies:
- name: backup-utils
  version: 2.3.4
  repository: https://this-is-tobi.github.io/helm-charts
  condition: backup-utils.enabled
```

**Using OCI Registry (Recommended):**
```yaml
# Chart.yaml
dependencies:
- name: backup-utils
  version: 2.3.4
  repository: oci://ghcr.io/this-is-tobi/helm-charts
  condition: backup-utils.enabled
```

`values.yaml`:

```yaml
backup-utils:
  enabled: true
  backups:
    myBackup:
      enabled: true
      type: postgres
      # ... configuration
```

## Configuration

### Configuration Structure

The chart uses a **map-based configuration** where each key under `backups` represents one backup job:

- **Map Keys**: Each key becomes a backup job identifier (converted to kebab-case)
- **Kubernetes Resources**: Each backup creates 1 CronJob + 1 ConfigMap + 1 Secret
- **Independent Config**: Each backup has its own schedule, type, env vars, and resources
- **Global Values**: Use `global.env` and `global.secrets` for shared configuration

**Example Structure:**

```yaml
global:
  env:
    S3_PATH_STYLE: "true"
    RETENTION: "30d"
  secrets:
    # Shared S3 credentials
    S3_ENDPOINT: "https://s3.amazonaws.com"
    S3_ACCESS_KEY: "AKIAIOSFODNN7EXAMPLE"
    S3_SECRET_KEY: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
    S3_BUCKET_NAME: "my-backups"

backups:
  postgresProduction:    # Creates: <release>-postgres-production
    enabled: true
    type: postgres
    job:
      schedule: "0 2 * * *"
    secrets:
      DB_HOST: "postgres"
      DB_PORT: "5432"
      DB_NAME: "myapp"
      DB_USER: "backup_user"
      DB_PASS: "password"
      S3_BUCKET_PREFIX: "postgres/prod/"
 
  vaultBackup:          # Creates: <release>-vault-backup
    enabled: true
    type: vault
    job:
      schedule: "0 3 * * *"
    secrets:
      VAULT_ADDR: "https://vault:8200"
      VAULT_TOKEN: "hvs.xxx"
      S3_BUCKET_PREFIX: "vault/"
```

## Usage Examples

### Example 1: Basic PostgreSQL Backup

Daily PostgreSQL backup at 2 AM with 30-day retention:

```yaml
backups:
  postgresProduction:
    enabled: true
    type: postgres
    job:
      schedule: "0 2 * * *"  # Daily at 2 AM UTC
      timeZone: "Europe/Paris"
    env:
      RETENTION: "30d"
    secrets:
      # PostgreSQL connection
      DB_HOST: "postgres.default.svc.cluster.local"
      DB_PORT: "5432"
      DB_NAME: "production"
      DB_USER: "backup_user"
      DB_PASS: "secure_password"
      # S3 destination
      S3_ENDPOINT: "https://s3.amazonaws.com"
      S3_ACCESS_KEY: "AKIAIOSFODNN7EXAMPLE"
      S3_SECRET_KEY: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
      S3_BUCKET_NAME: "company-backups"
      S3_BUCKET_PREFIX: "postgres/production/"
    resources:
      requests:
        memory: "256Mi"
        cpu: "200m"
      limits:
        memory: "1Gi"
        cpu: "500m"
```

### Example 2: MariaDB/MySQL Backup

Daily MariaDB backup at 2:30 AM with custom dump arguments:

```yaml
backups:
  mariadbProduction:
    enabled: true
    type: mariadb
    job:
      schedule: "30 2 * * *"  # Daily at 2:30 AM UTC
      timeZone: "Europe/Paris"
    env:
      RETENTION: "30d"
      DB_DUMP_ARGS: "--single-transaction --routines --triggers --events"  # Optional custom args
    secrets:
      # MariaDB/MySQL connection
      DB_HOST: "mariadb.default.svc.cluster.local"
      DB_PORT: "3306"
      DB_NAME: "production"
      DB_USER: "backup_user"
      DB_PASS: "secure_password"
      # S3 destination
      S3_ENDPOINT: "https://s3.amazonaws.com"
      S3_ACCESS_KEY: "AKIAIOSFODNN7EXAMPLE"
      S3_SECRET_KEY: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
      S3_BUCKET_NAME: "company-backups"
      S3_BUCKET_PREFIX: "mariadb/production/"
    resources:
      requests:
        memory: "256Mi"
        cpu: "200m"
      limits:
        memory: "1Gi"
        cpu: "500m"
```

### Example 3: Vault Snapshot Backup

Hourly Vault snapshots with 7-day retention:

```yaml
backups:
  vaultSnapshots:
    enabled: true
    type: vault
    job:
      schedule: "0 * * * *"  # Every hour
      successfulJobsHistoryLimit: 5
    env:
      RETENTION: "7d"
    secrets:
      VAULT_ADDR: "https://vault.default.svc.cluster.local:8200"
      VAULT_TOKEN: "hvs.CAESIxxxxxxxxxxxxxx"
      VAULT_EXTRA_ARGS: "-namespace=admin"
      # S3 destination
      S3_ENDPOINT: "https://minio.storage.svc.cluster.local:9000"
      S3_ACCESS_KEY: "minio-admin"
      S3_SECRET_KEY: "minio-secret"
      S3_BUCKET_NAME: "vault-backups"
      S3_BUCKET_PREFIX: "snapshots/"
```

### Example 4: Qdrant Vector Database Backup

Backup specific Qdrant collection daily:

```yaml
backups:
  qdrantVectors:
    enabled: true
    type: qdrant
    job:
      schedule: "0 3 * * *"  # Daily at 3 AM
    env:
      RETENTION: "14d"
    secrets:
      QDRANT_URL: "https://qdrant.default.svc.cluster.local:6333"
      QDRANT_API_KEY: "your-api-key-here"
      QDRANT_COLLECTION: "embeddings"  # Specific collection or empty for all
      # S3 destination
      S3_ENDPOINT: "https://s3.amazonaws.com"
      S3_ACCESS_KEY: "AKIAIOSFODNN7EXAMPLE"
      S3_SECRET_KEY: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
      S3_BUCKET_NAME: "ai-backups"
      S3_BUCKET_PREFIX: "qdrant/vectors/"
```

### Example 5: S3-to-S3 Bucket Sync

Sync data from one S3 bucket to another (cross-region backup):

```yaml
backups:
  s3CrossRegion:
    enabled: true
    type: s3
    job:
      schedule: "0 4 * * *"  # Daily at 4 AM
    env:
      RETENTION: "90d"
      RCLONE_EXTRA_ARGS: "--transfers=8 --checkers=16"
    secrets:
      # Source S3 bucket
      SOURCE_S3_ENDPOINT: "https://s3.us-west-2.amazonaws.com"
      SOURCE_S3_ACCESS_KEY: "AKIAIOSFODNN7SOURCE"
      SOURCE_S3_SECRET_KEY: "source-secret-key"
      SOURCE_S3_BUCKET_NAME: "production-data"
      SOURCE_S3_BUCKET_PREFIX: "uploads/"
      # Destination S3 bucket (different region for DR)
      S3_ENDPOINT: "https://s3.eu-central-1.amazonaws.com"
      S3_ACCESS_KEY: "AKIAIOSFODNN7DEST"
      S3_SECRET_KEY: "destination-secret-key"
      S3_BUCKET_NAME: "dr-backups"
      S3_BUCKET_PREFIX: "production-uploads/"
```

### Example 6: Multiple Backups with Global Configuration

Share S3 credentials across multiple backup jobs:

```yaml
# Global configuration (shared by all backups)
global:
  env:
    S3_PATH_STYLE: "true"
    RETENTION: "30d"
  secrets:
    # Common S3 destination
    S3_ENDPOINT: "https://s3.amazonaws.com"
    S3_ACCESS_KEY: "AKIAIOSFODNN7EXAMPLE"
    S3_SECRET_KEY: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
    S3_BUCKET_NAME: "company-backups"

# Individual backup jobs
backups:
  postgresProduction:
    enabled: true
    type: postgres
    job:
      schedule: "0 2 * * *"
    secrets:
      DB_HOST: "postgres.prod.svc"
      DB_PORT: "5432"
      DB_NAME: "production"
      DB_USER: "backup_user"
      DB_PASS: "pg-password"
      S3_BUCKET_PREFIX: "postgres/production/"
 
  postgresStaging:
    enabled: true
    type: postgres
    job:
      schedule: "0 3 * * *"
    env:
      RETENTION: "7d"  # Override global retention
    secrets:
      DB_HOST: "postgres.staging.svc"
      DB_PORT: "5432"
      DB_NAME: "staging"
      DB_USER: "backup_user"
      DB_PASS: "pg-password"
      S3_BUCKET_PREFIX: "postgres/staging/"
 
  vaultCluster:
    enabled: true
    type: vault
    job:
      schedule: "0 */6 * * *"  # Every 6 hours
    secrets:
      VAULT_ADDR: "https://vault:8200"
      VAULT_TOKEN: "hvs.xxx"
      S3_BUCKET_PREFIX: "vault/snapshots/"
 
  qdrantEmbeddings:
    enabled: true
    type: qdrant
    job:
      schedule: "0 4 * * *"
    secrets:
      QDRANT_URL: "https://qdrant:6333"
      QDRANT_API_KEY: "api-key"
      S3_BUCKET_PREFIX: "qdrant/"
```

## Advanced Features

### Custom Resource Limits

Adjust CPU and memory based on backup size:

```yaml
backups:
  largeDatabase:
    enabled: true
    type: postgres
    resources:
      requests:
        memory: "512Mi"
        cpu: "500m"
      limits:
        memory: "2Gi"
        cpu: "1000m"
```

### Timezone Support

Run backups in specific timezone:

```yaml
backups:
  europeBackup:
    enabled: true
    type: postgres
    job:
      schedule: "0 2 * * *"  # 2 AM in specified timezone
      timeZone: "Europe/Paris"
```

### Performance Tuning

Optimize rclone for large transfers:

```yaml
backups:
  largeFiles:
    enabled: true
    type: s3
    env:
      RCLONE_EXTRA_ARGS: "--transfers=16 --checkers=32 --buffer-size=256M"
```

### Streaming Upload Limitations

When backing up databases using streaming methods (PostgreSQL with `pg_dump`, MariaDB with `mariadb-dump`), rclone uses multipart uploads with a default chunk size of **5 MiB**. Due to S3 API limitations (maximum 10,000 parts per upload), this imposes a maximum file size constraint.

**Default Configuration:**
- **Chunk size**: 5 MiB (default `--s3-chunk-size`)
- **Maximum parts**: 10,000 (S3 limit)
- **Maximum backup size**: ~48.8 GiB (5 MiB × 10,000 parts)

**For Larger Databases:**

If your database dump exceeds ~48 GiB, you must increase the chunk size using `RCLONE_EXTRA_ARGS`:

```yaml
backups:
  largeDatabaseBackup:
    enabled: true
    type: postgres  # or mariadb
    env:
      # For databases up to ~600 GB
      RCLONE_EXTRA_ARGS: "--s3-chunk-size=64M"
     
      # For databases up to ~1.2 TB
      # RCLONE_EXTRA_ARGS: "--s3-chunk-size=128M"
     
      # For databases up to ~2.4 TB
      # RCLONE_EXTRA_ARGS: "--s3-chunk-size=256M"
    resources:
      requests:
        memory: "1Gi"  # Increase memory for larger chunks
        cpu: "500m"
      limits:
        memory: "4Gi"
        cpu: "2000m"
```

**Memory Considerations:**

Larger chunk sizes require more memory. The formula for memory usage is approximately:
```
Memory = chunk_size × upload_concurrency × transfers
```

With default settings (`--s3-upload-concurrency=4`, `--transfers=4`):
- 5 MiB chunks: ~80 MiB memory
- 64 MiB chunks: ~1 GiB memory
- 128 MiB chunks: ~2 GiB memory
- 256 MiB chunks: ~4 GiB memory

**Quick Reference Table:**

| Chunk Size | Max Backup Size | Recommended Memory | Use Case |
|------------|----------------|-------------------|----------|
| 5 MiB (default) | ~48.8 GiB | 256 MiB | Small to medium databases |
| 64 MiB | ~625 GiB | 1 GiB | Large databases |
| 128 MiB | ~1.25 TiB | 2 GiB | Very large databases |
| 256 MiB | ~2.5 TiB | 4 GiB | Enterprise databases |

**Note:** This limitation only affects streaming backups (PostgreSQL, MariaDB). S3-to-S3 sync and other backup types that use file-based uploads are not affected as rclone can determine the file size in advance.

### Job History and Retry

Configure job execution history and retries:

```yaml
backups:
  criticalBackup:
    enabled: true
    type: postgres
    job:
      schedule: "0 2 * * *"
      successfulJobsHistoryLimit: 5   # Keep last 5 successful runs
      failedJobsHistoryLimit: 10      # Keep last 10 failed runs
      backoffLimit: 5                 # Retry 5 times on failure
      concurrencyPolicy: "Forbid"     # Don't run if previous job still running
```

### Security Context

Run backup pods with specific user/group:

```yaml
backups:
  secureBackup:
    enabled: true
    type: postgres
    podSecurityContext:
      fsGroup: 1000
      runAsUser: 1000
      runAsNonRoot: true
    container:
      securityContext:
        allowPrivilegeEscalation: false
        capabilities:
          drop:
          - ALL
        readOnlyRootFilesystem: true
```

### Environment Variables from External Sources

Load configuration from existing ConfigMaps or Secrets:

```yaml
backups:
  externalConfig:
    enabled: true
    type: postgres
    envFrom:
    - configMapRef:
        name: backup-common-config
    - secretRef:
        name: postgres-credentials
```

## Best Practices

### 1. Security

**Use Kubernetes Secrets:**
```yaml
# Create external secret
kubectl create secret generic postgres-backup-creds \
  --from-literal=DB_HOST=postgres.svc \
  --from-literal=DB_PASS=secure-password

# Reference in values
backups:
  myBackup:
    envFrom:
    - secretRef:
        name: postgres-backup-creds
```

**Enable Pod Security Context:**
```yaml
backups:
  secureBackup:
    podSecurityContext:
      runAsNonRoot: true
      runAsUser: 1000
      fsGroup: 1000
    container:
      securityContext:
        allowPrivilegeEscalation: false
        capabilities:
          drop: [ALL]
```

### 2. Retention Strategy

**Consider backup frequency and storage costs:**
- **Critical data**: 30-90 days retention
- **Development**: 7-14 days retention 
- **Logs/metrics**: 1-7 days retention

**Example retention policies:**
```yaml
global:
  env:
    RETENTION: "30d"  # Default for all

backups:
  productionDB:
    env:
      RETENTION: "90d"  # Override for critical data
 
  stagingDB:
    env:
      RETENTION: "7d"   # Shorter for non-prod
```

### 3. Scheduling

**Avoid overlap and resource contention:**
```yaml
backups:
  backup1:
    job:
      schedule: "0 2 * * *"   # 2 AM
  backup2:
    job:
      schedule: "0 3 * * *"   # 3 AM (staggered)
  backup3:
    job:
      schedule: "0 4 * * *"   # 4 AM
```

**Use timezone for predictable execution:**
```yaml
backups:
  myBackup:
    job:
      schedule: "0 2 * * *"
      timeZone: "Europe/Paris"  # 2 AM Paris time
```

### 4. Resource Allocation

**Size based on data volume:**
- **Small databases (<1GB)**: 128Mi memory, 100m CPU
- **Medium databases (1-10GB)**: 512Mi memory, 250m CPU
- **Large databases (>10GB)**: 1Gi+ memory, 500m+ CPU

**Monitor and adjust:**
```bash
# Check actual usage
kubectl top pod -l app.kubernetes.io/name=backup-utils
```

### 5. Monitoring and Alerting

**Check job status:**
```bash
# List all cronjobs
kubectl get cronjobs -l app.kubernetes.io/name=backup-utils

# Check job history
kubectl get jobs -l app.kubernetes.io/name=backup-utils

# View logs
kubectl logs -l job-name=<job-name>
```

**Add custom labels for monitoring:**
```yaml
backups:
  critical:
    jobLabels:
      backup-priority: critical
      alert-on-failure: "true"
```

### 6. Disaster Recovery Testing

**Regularly test restores:**
1. Download backup from S3
2. Restore to test environment
3. Verify data integrity
4. Document restore procedure

**Example restore commands:**
```bash
# PostgreSQL
pg_restore -h localhost -U postgres -d testdb backup.dump

# S3 sync
rclone sync s3:backups/postgres/ ./restore/

# Vault
vault operator raft snapshot restore backup.snap
```

## Configuration Reference

### Retention Format

Uses rclone duration format:
- `7d` - 7 days
- `168h` - 168 hours (1 week)
- `2w` - 2 weeks (if supported by rclone)
- `10080m` - 10,080 minutes (1 week)

### Cron Schedule Format

Standard cron expression: `minute hour day month weekday`

**Common patterns:**
- `"0 2 * * *"` - Daily at 2 AM
- `"0 */6 * * *"` - Every 6 hours
- `"0 2 * * 0"` - Weekly on Sunday at 2 AM
- `"0 2 1 * *"` - Monthly on 1st at 2 AM
- `"*/30 * * * *"` - Every 30 minutes

### S3 Provider Examples

**AWS S3:**
```yaml
S3_ENDPOINT: "https://s3.amazonaws.com"
S3_PATH_STYLE: "false"  # Use virtual-hosted style
```

**MinIO:**
```yaml
S3_ENDPOINT: "https://minio.example.com:9000"
S3_PATH_STYLE: "true"
```

**Wasabi:**
```yaml
S3_ENDPOINT: "https://s3.wasabisys.com"
S3_PATH_STYLE: "true"
```

**Backblaze B2:**
```yaml
S3_ENDPOINT: "https://s3.us-west-002.backblazeb2.com"
S3_PATH_STYLE: "true"
```

## Troubleshooting

### Common Issues

**Backup Job Not Running:**
```bash
# Check CronJob status
kubectl describe cronjob <cronjob-name>

# Check for suspended jobs
kubectl get cronjobs -o json | jq '.items[] | select(.spec.suspend==true)'

# Verify schedule syntax
kubectl get cronjob <name> -o jsonpath='{.spec.schedule}'
```

**Pod Crashes or OOM:**
```bash
# Check pod events
kubectl describe pod <pod-name>

# Check resource usage
kubectl top pod <pod-name>

# Increase memory limits
```

**S3 Connection Failures:**
- Verify S3 endpoint URL is correct and accessible
- Check credentials have write permissions
- Test S3 connectivity from within cluster:
```bash
kubectl run -it --rm debug --image=amazon/aws-cli --restart=Never -- \
  s3 ls --endpoint-url=https://s3.example.com
```

**PostgreSQL Connection Issues:**
- Verify database host is resolvable from backup pod
- Check firewall/network policies allow connection
- Test connection:
```bash
kubectl run -it --rm psql --image=postgres:latest --restart=Never -- \
  psql -h postgres.default.svc -U backup_user -d myapp
```

**Retention Not Working:**
- Verify RETENTION format is correct (e.g., `7d`, `168h`)
- Check rclone logs for cleanup operations
- Ensure S3 credentials have delete permissions

## Values

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
| backups | object | `{}` |  |
| extraObjects | list | `[]` | Add extra specs dynamically to this chart. |
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
