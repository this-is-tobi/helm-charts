# vso-utils

![Version: 0.0.1](https://img.shields.io/badge/Version-0.0.1-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 0.1.0](https://img.shields.io/badge/AppVersion-0.1.0-informational?style=flat-square)

A Helm chart for effortless deployment of Vault Secret Operator utilities.

## Requirements

| Repository | Name | Version |
|------------|------|---------|
| https://helm.releases.hashicorp.com | vso(vault-secrets-operator) | >=0.10.0 |

## Installing the Chart

### CLI

```sh
helm repo add tobi https://this-is-tobi.github.io/helm-charts
helm install <release_name> tobi/vso-utils
```

### ArgoCD

`application.yaml` :

```yaml
[...]
sources:
- repoURL: https://this-is-tobi.github.io/helm-charts
  chart: vso-utils
  targetRevision: 0.0.1
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
- name: vso-utils
  version: 0.0.1
  repository: https://this-is-tobi.github.io/helm-charts
  condition: vso-utils.enabled
```

`values.yaml`:

```yaml
[...]
vso-utils:
  enabled: true
```

## Values

### VaultStaticSecrets

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| vaultStaticSecrets[0].annotations | object | `{}` | Additional annotations for VaultStaticSecret. |
| vaultStaticSecrets[0].destination.annotations | object | `{}` | Annotations to apply to the Secret. |
| vaultStaticSecrets[0].destination.create | bool | `true` | Create the destination Secret. If the Secret already exists this should be set to false. |
| vaultStaticSecrets[0].destination.labels | object | `{}` | Labels to apply to the Secret. |
| vaultStaticSecrets[0].destination.name | string | `""` | Name of the Secret. |
| vaultStaticSecrets[0].destination.overwrite | bool | `false` | Overwrite the destination Secret if it exists and Create is true. This is useful when migrating to VSO from a previous secret deployment strategy. |
| vaultStaticSecrets[0].destination.transformation | object | `{}` | Transformation provides configuration for transforming the secret data before it is stored in the Destination. |
| vaultStaticSecrets[0].destination.type | string | `"Opaque"` | Type of Kubernetes Secret. |
| vaultStaticSecrets[0].hmacSecretData | bool | `true` | HMACSecretData determines whether the Operator computes the HMAC of the Secret's data. The MAC value will be stored in the resource's Status.SecretMac field, and will be used for drift detection and during incoming Vault secret comparison. Enabling this feature is recommended to ensure that Secret's data stays consistent with Vault. |
| vaultStaticSecrets[0].labels | object | `{}` | Additional labels for VaultStaticSecret. |
| vaultStaticSecrets[0].mount | string | `""` | Mount for the secret in Vault. |
| vaultStaticSecrets[0].namespace | string | `""` | Namespace of the secrets engine mount in Vault. If not set, the namespace that's part of VaultAuth resource will be inferred. |
| vaultStaticSecrets[0].path | string | `""` | Path of the secret in Vault, corresponds to the `path`` parameter for, [kv-v1](https://developer.hashicorp.com/vault/api-docs/secret/kv/kv-v1#read-secret) or [kv-v2](https://developer.hashicorp.com/vault/api-docs/secret/kv/kv-v2#read-secret-version). |
| vaultStaticSecrets[0].refreshAfter | string | `""` | RefreshAfter a period of time, in duration notation e.g. 30s, 1m, 24h. |
| vaultStaticSecrets[0].rolloutRestartTargets | list | `[]` | RolloutRestartTargets should be configured whenever the application(s) consuming the Vault secret does not support dynamically reloading a rotated secret. In that case one, or more RolloutRestartTarget(s) can be configured here. The Operator will trigger a "rollout-restart" for each target whenever the Vault secret changes between reconciliation events. All configured targets will be ignored if HMACSecretData is set to false. See RolloutRestartTarget for more details. |
| vaultStaticSecrets[0].type | string | `"kv-v2"` | Type of the Vault static secret (should be `kv-v1` or `kv-v2`). |
| vaultStaticSecrets[0].vaultAuthRef | string | `""` | VaultAuthRef to the VaultAuth resource, can be prefixed with a namespace, eg: `namespaceA/vaultAuthRefB`. If no namespace prefix is provided it will default to the namespace of the VaultAuth CR. If no value is specified for VaultAuthRef the Operator will default to the default VaultAuth, configured in the operator's namespace. |
| vaultStaticSecrets[0].version | string | `nil` | Version of the secret to fetch. Corresponds to `version` query parameter: [version](https://developer.hashicorp.com/vault/api-docs/secret/kv/kv-v2#version). Only valid for type kv-v2. |

### Other Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| fullnameOverride | string | `""` | String to fully override the default application name. |
| nameOverride | string | `""` | Provide a name in place of the default application name. |
| vso.enabled | bool | `false` | Whether or not cnpg operator should be deployed (See. https://artifacthub.io/packages/helm/hashicorp/vault-secrets-operator?modal=values). |

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| this-is-tobi | <this-is-tobi@proton.me> | <https://this-is-tobi.com> |

## Sources

**Source code:**

* <https://github.com/this-is-tobi/helm-charts>
* <https://artifacthub.io/packages/helm/hashicorp/vault-secrets-operator>
* <https://developer.hashicorp.com/vault/docs/deploy/kubernetes/vso>

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
