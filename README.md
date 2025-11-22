# Helm charts :anchor:

This repository hosts a set of personal Helm Charts available through:
- **Helm Repository**: [https://this-is-tobi.github.io/helm-charts](https://this-is-tobi.github.io/helm-charts) (GitHub Pages)
- **OCI Registry**: `ghcr.io/this-is-tobi/helm-charts` (GitHub Container Registry)

> [!TIP]
> See charts details [here](https://this-is-tobi.github.io/helm-charts/index.yaml).

## Chart list

| Chart                                 | Application                                                             | Description                         | ArtifactHub                                                                        |
| ------------------------------------- | ----------------------------------------------------------------------- | ----------------------------------- | ---------------------------------------------------------------------------------- |
| [backup-utils](./charts/backup-utils) | -                                                                       | Easy backup tools deployment.       | [link](https://artifacthub.io/packages/helm/this-is-tobi-helm-charts/backup-utils) |
| [cnpg-cluster](./charts/cnpg-cluster) | [CNPG](https://cloudnative-pg.io)                                       | Easy CNPG cluster deployment.       | [link](https://artifacthub.io/packages/helm/this-is-tobi-helm-charts/cnpg-cluster) |
| [dashy](./charts/dashy)               | [Dashy](https://github.com/lissy93/dashy)                               | A self-hostable personal dashboard. | [link](https://artifacthub.io/packages/helm/this-is-tobi-helm-charts/dashy)        |
| [homarr](./charts/homarr)             | [Homarr](https://github.com/ajnart/homarr)                              | A self-hostable personal dashboard. | [link](https://artifacthub.io/packages/helm/this-is-tobi-helm-charts/homarr)       |
| [vso-utils](./charts/vso-utils)       | [VSO](https://developer.hashicorp.com/vault/docs/deploy/kubernetes/vso) | Easy VSO objects deployment.        | [link](https://artifacthub.io/packages/helm/this-is-tobi-helm-charts/vso-utils)    |

## Usage

### Traditional Helm Repository

```sh
# Add repository
helm repo add tobi https://this-is-tobi.github.io/helm-charts
helm repo update

# Search and install
helm search repo tobi
helm install <release_name> tobi/<chart_name>
```

### OCI Registry

```sh
# Install directly from OCI registry
helm install <release_name> oci://ghcr.io/this-is-tobi/helm-charts/<chart_name> --version <version>

# Example
helm install my-db oci://ghcr.io/this-is-tobi/helm-charts/cnpg-cluster --version 1.5.0
```

> [!TIP]
> OCI installation doesn't require `helm repo add` and provides better performance and security.

### Chart Signatures

All charts are signed using GPG for authenticity and integrity verification.

**GPG Key Information:**
- Key ID: `54029E3057EBFE1FA2781C066F5BD8A9D2134DCF`
- Public key: [ci/configs/helm-charts-signing-key.asc](./ci/configs/helm-charts-signing-key.asc)

**Verifying Traditional Helm Charts (.tgz):**
```sh
# Import the public key
curl -s https://raw.githubusercontent.com/this-is-tobi/helm-charts/main/ci/configs/helm-charts-signing-key.asc | gpg --import

# Verify a chart
helm verify <chart-name>-<version>.tgz

# Or during installation
helm install --verify <release-name> <chart-name>
```

**Verifying OCI Images:**

OCI artifacts are signed using [Cosign](https://docs.sigstore.dev/cosign/overview/) with keyless signing (OIDC).

```sh
# Install cosign (if not already installed)
# macOS: brew install cosign
# Linux: https://docs.sigstore.dev/cosign/installation/

# Verify OCI chart signature
cosign verify \
  --certificate-identity-regexp="https://github.com/this-is-tobi/helm-charts" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  ghcr.io/this-is-tobi/helm-charts/<chart-name>:<version>
```

### Helm Dependencies

You can use these charts as dependencies in your own Helm charts.

**Using Traditional Helm Repository:**
```yaml
# Chart.yaml
dependencies:
  - name: <chart_name>
    version: "<version>"
    repository: "https://this-is-tobi.github.io/helm-charts"
```

**Using OCI Registry (Recommended):**
```yaml
# Chart.yaml
dependencies:
  - name: <chart_name>
    version: "<version>"
    repository: "oci://ghcr.io/this-is-tobi/helm-charts"
```

Then update dependencies:
```sh
helm dependency update
```

### ArgoCD

**Using Helm Repository:**
```yaml
sources:
- repoURL: https://this-is-tobi.github.io/helm-charts
  chart: <chart_name>
  targetRevision: <version>
  helm:
    releaseName: <release_name>
    values: ""
```

**Using OCI Registry:**
```yaml
sources:
- repoURL: ghcr.io/this-is-tobi/helm-charts
  chart: <chart_name>
  targetRevision: <version>
  helm:
    releaseName: <release_name>
    values: ""
```

## Dependencies updates

A script is available to help upgrade charts dependencies:

```sh
./ci/scripts/update-charts-dependencies.sh
```

## Template

A [template folder](./template/) is available for easy integration of new chart, to use it follow the steps bellow:

1. Copy the template directory:
    ```sh
    # Copy the template chart
    cp -R ./template ./charts/<chart_name>

    # Rename the chart
    sed -i "s/chartname/<chart_name>/g" ./charts/<chart_name>/Chart.yaml
    ```

2. Update the service name:
    ```sh
    # Rename the templates directory
    mv ./charts/<chart_name>/templates/servicename ./charts/<chart_name>/templates/<service_name>

    # Update service name in template files
    find ./charts/<chart_name>/templates/<service_name> -type f -exec sed -i "s/servicename/<service_name>/g" ./charts/<chart_name>/values.yaml {} \;

    # Update service name in values file
    yq eval ".<service_name> = .servicename | del(.servicename)" -i ./charts/<chart_name>/values.yaml
    sed -i "s/servicename/<service_name>/g" ./charts/<chart_name>/values.yaml
    ```

3. Optionally add another service:
    ```sh
    # Clone additional service
    cp -R ./template/templates/servicename ./charts/<chart_name>/templates/<other_service_name>

    # Update service name in template files
    find ./charts/<chart_name>/templates/<other_service_name> -type f -exec sed -i "s/servicename/<other_service_name>/g" ./charts/<chart_name>/values.yaml {} \;

    # Update service name in values file
    yq eval ".<other_service_name> = load(\"./template/values.yaml\").servicename" -i ./charts/<chart_name>/values.yaml
    sed -i "s/servicename/<other_service_name>/g" ./charts/<chart_name>/values.yaml
    ```

4. Update chart name:
    ```sh
    # Update chart name in values
    sed -i "s/chartname/<chart_name>/g" ./charts/<chart_name>/values.yaml
    ```

> Do not forget to change `<chart_name>`, `<service_name>` and `<other_service_name>` placeholders.

> [!TIP]
> A shell script is also available to generate a new Helm chart:
>   ```sh
>   curl -s https://raw.githubusercontent.com/this-is-tobi/tools/main/shell/helm-template.sh \                      
>       | bash -s -- -c '<chart_name>' -s '<service_name>' -a '<additional_service_name>'
>   ```
>
> Notes:
>    - `-c` flags set the chart name *(ex: `my-app`)*.
> 
>    - `-s` flags set the service name *(ex: `api`)*.
> 
>    - `-a` (optional) flags set the additional service name *(ex: `front`)*.

## Contributions

- Each PR is associated with a pipeline that checks the `lint` + `helm-docs`.
- When a merge is performed on the `main` branch, the release pipeline publishes the new version of the chart(s) affected and updates the Helm Repo (`gh-pages` branch).

> [!TIP]  
> The version in the `Chart.yaml` file must be modified before the merge to main, otherwise the release pipeline will error on version duplication.
