# vso-utils

![Version: 1.1.0](https://img.shields.io/badge/Version-1.1.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.10.0](https://img.shields.io/badge/AppVersion-0.10.0-informational?style=flat-square)

Production-ready Helm chart for managing HashiCorp Vault Secret Operator resources - sync static secrets, generate dynamic credentials, issue PKI certificates, and configure Vault authentication.

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| https://helm.releases.hashicorp.com | vso(vault-secrets-operator) | >=0.10.0 |

## Overview

This Helm chart provides a comprehensive and production-ready solution for deploying Vault Secret Operator (VSO) resources in Kubernetes. It simplifies the management of secrets from HashiCorp Vault by providing:

- **VaultStaticSecret**: Sync static KV secrets from Vault to Kubernetes Secrets
- **VaultDynamicSecret**: Generate dynamic credentials (databases, cloud providers, etc.)
- **VaultPKISecret**: Issue and renew PKI certificates automatically
- **VaultAuth**: Configure Vault authentication methods
- **VaultConnection**: Define Vault server connection settings

### Supported VSO Resources

| Resource Type | Description | Use Case |
|---------------|-------------|----------|
| VaultStaticSecret | Syncs KV-v1/KV-v2 secrets | Application configuration, API keys |
| VaultDynamicSecret | Generates short-lived credentials | Database passwords, cloud IAM |
| VaultPKISecret | Issues X.509 certificates | TLS/mTLS, service mesh |
| VaultAuth | Configures authentication | Kubernetes, JWT, AppRole auth |
| VaultConnection | Defines Vault endpoints | Multi-cluster, HA Vault setups |

## Installing the Chart

### Prerequisites

- Kubernetes 1.29+
- Helm 3.0+
- Vault Secret Operator installed (can be enabled via this chart)
- HashiCorp Vault server accessible from your cluster

### CLI

**Using Traditional Helm Repository:**
```sh
helm repo add tobi https://this-is-tobi.github.io/helm-charts
helm repo update
helm install <release_name> tobi/vso-utils
```

**Using OCI Registry (Recommended):**
```sh
helm install <release_name> oci://ghcr.io/this-is-tobi/helm-charts/vso-utils --version 1.1.0
```

### ArgoCD

**Using Helm Repository:**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: vso-utils
spec:
  project: default
  sources:
  - repoURL: https://this-is-tobi.github.io/helm-charts
    chart: vso-utils
    targetRevision: 1.1.0
    helm:
      releaseName: <release_name>
      values: |
        vaultStaticSecrets:
          appConfig:
            mount: secret
            vaultAuthRef: default
            path: app/config
            destination:
              name: app-config
  destination:
    server: https://kubernetes.default.svc
    namespace: default
```

**Using OCI Registry:**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: vso-utils
spec:
  project: default
  sources:
  - repoURL: ghcr.io/this-is-tobi/helm-charts
    chart: vso-utils
    targetRevision: 1.1.0
    helm:
      releaseName: <release_name>
      values: |
        vaultStaticSecrets:
          appConfig:
            mount: secret
            vaultAuthRef: default
            path: app/config
            destination:
              name: app-config
  destination:
    server: https://kubernetes.default.svc
    namespace: default
```

### Helm Dependency

**Using Helm Repository:**
```yaml
# Chart.yaml
dependencies:
- name: vso-utils
  version: 1.1.0
  repository: https://this-is-tobi.github.io/helm-charts
  condition: vso-utils.enabled
```

**Using OCI Registry:**
```yaml
# Chart.yaml
dependencies:
- name: vso-utils
  version: 1.1.0
  repository: oci://ghcr.io/this-is-tobi/helm-charts
  condition: vso-utils.enabled
```

`values.yaml`:

```yaml
vso-utils:
  enabled: true
  vaultStaticSecrets:
    appConfig:
      mount: secret
      vaultAuthRef: default
      path: app/config
      destination:
        name: app-config
```

## Configuration

### Configuration Structure

Each VSO resource type (`vaultStaticSecrets`, `vaultDynamicSecrets`, etc.) is configured as a map where:
- **Each top-level key** represents one resource instance
- **The key name** becomes part of the Kubernetes resource name (converted to kebab-case)
- **The value** contains the resource-specific configuration

Example:
```yaml
vaultStaticSecrets:
  myAppConfig:      # Creates: <release-name>-vso-utils-my-app-config
    mount: secret
    path: app/config
    # ... configuration
  anotherSecret:    # Creates: <release-name>-vso-utils-another-secret
    mount: secret
    path: another/path
    # ... configuration
```

### Basic Usage Examples

#### 1. Static KV Secret (Application Configuration)

```yaml
vaultStaticSecrets:
  appConfig:
    mount: secret
    vaultAuthRef: default
    path: myapp/config
    type: kv-v2
    refreshAfter: 1h
    hmacSecretData: true
    destination:
      name: app-config
      create: true
```

This creates a Kubernetes Secret named `app-config` that syncs from `secret/myapp/config` in Vault.

#### 2. Dynamic Database Credentials

```yaml
vaultDynamicSecrets:
  postgresCredentials:
    mount: database
    vaultAuthRef: default
    path: creds/my-role
    renewalPercent: 67
    revoke: true
    rolloutRestartTargets:
    - kind: Deployment
      name: my-app
    destination:
      name: postgres-creds
      create: true
```

Generates fresh database credentials and restarts the deployment when rotated.

#### 3. TLS Certificate

```yaml
vaultPKISecrets:
  serviceTLS:
    mount: pki
    vaultAuthRef: default
    role: service-role
    commonName: myservice.example.com
    altNames:
    - "*.myservice.example.com"
    ttl: 720h
    expiryOffset: 24h
    destination:
      name: service-tls
      type: kubernetes.io/tls
      create: true
```

Issues a TLS certificate that auto-renews 24 hours before expiration.

#### 4. Complete Setup with Auth and Connection

```yaml
vaultConnection:
  default:
    address: https://vault.example.com:8200
    skipTLSVerify: false
    tls:
      caCertSecretRef: vault-ca-cert

vaultAuth:
  default:
    method: kubernetes
    mount: kubernetes
    params:
      role: my-app-role
      serviceAccount: default
      audiences: ["vault"]
    vaultConnectionRef: default

vaultStaticSecrets:
  appSecrets:
    mount: secret
    vaultAuthRef: default
    path: app/secrets
    destination:
      name: app-secrets
```

Complete configuration including Vault connection, authentication, and secret sync.

## Advanced Features

### Secret Transformation

Transform secret data before storing in Kubernetes:

```yaml
vaultStaticSecrets:
  appConfig:
    mount: secret
    path: app/config
    destination:
      name: app-config
      transformation:
        templates:
          config.json:
            text: |
              {
                "database": {
                  "host": "{{ .Secrets.db_host }}",
                  "port": {{ .Secrets.db_port }},
                  "username": "{{ .Secrets.db_user }}"
                }
              }
        includes:
        - "^api_.*"
        excludes:
        - ".*_internal$"
```

### Rollout Restarts

Automatically restart workloads when secrets change:

```yaml
vaultDynamicSecrets:
  dbCreds:
    mount: database
    path: creds/my-role
    hmacSecretData: true  # Required for rollout restarts
    rolloutRestartTargets:
    - kind: Deployment
      name: backend
    - kind: StatefulSet
      name: worker
    destination:
      name: db-credentials
```

### Multi-Namespace Deployments

Deploy VSO resources across namespaces:

```yaml
vaultStaticSecrets:
  prodConfig:
    namespace: production
    mount: secret
    path: prod/config
    destination:
      name: app-config
 
  devConfig:
    namespace: development
    mount: secret
    path: dev/config
    destination:
      name: app-config
```

## Security Best Practices

1. **Enable HMAC Secret Data**: Always set `hmacSecretData: true` for drift detection
2. **Use Specific Roles**: Create dedicated Vault roles with least-privilege policies
3. **Enable TLS**: Never set `skipTLSVerify: true` in production
4. **Rotate Credentials**: Use `VaultDynamicSecret` for auto-rotating credentials
5. **Namespace Isolation**: Deploy VSO resources in appropriate namespaces
6. **Secret Transformation**: Use `excludes` patterns to filter sensitive data
7. **Audit Logging**: Enable Vault audit logs to track secret access

## Troubleshooting

### Common Issues

**Secret Not Syncing**:
- Verify VaultAuth is configured correctly
- Check Vault policies allow read access to the secret path
- Review VSO operator logs: `kubectl logs -n vault-secrets-operator-system deployment/vault-secrets-operator-controller-manager`

**Authentication Failures**:
- Ensure Kubernetes auth is enabled in Vault: `vault auth enable kubernetes`
- Verify the service account has proper RBAC permissions
- Check the VaultAuth resource status: `kubectl describe vaultauth <name>`

**Certificate Renewal Issues**:
- Verify `expiryOffset` is less than certificate TTL
- Check PKI role configuration in Vault
- Ensure network connectivity to Vault

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| extraObjects | list | `[]` | Add extra specs dynamically to this chart. |
| fullnameOverride | string | `""` | String to fully override the default application name. |
| nameOverride | string | `""` | Provide a name in place of the default application name. |
| vaultAuth | object | `{}` |  |
| vaultConnection | object | `{}` |  |
| vaultDynamicSecrets | object | `{}` |  |
| vaultPKISecrets | object | `{}` |  |
| vaultStaticSecrets | object | `{}` |  |
| vso.enabled | bool | `false` | Enable deployment of Vault Secrets Operator. |

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| this-is-tobi | <this-is-tobi@proton.me> | <https://this-is-tobi.com> |

## Sources

**Official Documentation**:
- [Vault Secrets Operator](https://developer.hashicorp.com/vault/docs/platform/k8s/vso)
- [VSO API Reference](https://developer.hashicorp.com/vault/docs/platform/k8s/vso/api-reference)

**Source Code**:

* <https://github.com/this-is-tobi/helm-charts>
* <https://artifacthub.io/packages/helm/hashicorp/vault-secrets-operator>
* <https://developer.hashicorp.com/vault/docs/platform/k8s/vso>
* <https://github.com/hashicorp/vault-secrets-operator>

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)

