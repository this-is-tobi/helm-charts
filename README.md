# Helm charts :anchor:

This repository hosts a set of personal Helm Charts and exposes a Helm Repository at [https://this-is-tobi.github.io/helm-charts](https://this-is-tobi.github.io/helm-charts) thanks to Github Pages and the Github Action [chart releaser](https://github.com/helm/chart-releaser-action).

> [!TIP]
> See charts details [here](https://this-is-tobi.github.io/helm-charts/index.yaml).

## Chart list

| Chart                                 | Application                                | Description                         | Last version |
| ------------------------------------- | ------------------------------------------ | ----------------------------------- | ------------ |
| [backup-utils](./charts/backup-utils) | -                                          | Easy backup tools deployment.       | `1.2.4`      |
| [cnpg-cluster](./charts/cnpg-cluster) | [CNPG](https://cloudnative-pg.io)          | Easy CNPG cluster deployment.       | `0.10.3`     |
| [dashy](./charts/dashy)               | [Dashy](https://github.com/lissy93/dashy)  | A self-hostable personal dashboard. | `0.1.9`      |
| [homarr](./charts/homarr)             | [Homarr](https://github.com/ajnart/homarr) | A self-hostable personal dashboard. | `0.1.10`     |

## Usage

### CLI

```sh
helm repo add tobi https://this-is-tobi.github.io/helm-charts
helm search repo tobi
helm install <release_name> tobi/<chart_name>
```

### ArgoCD

```yaml
[...]
sources:
- repoURL: https://this-is-tobi.github.io/helm-charts
  chart: <chart_name>
  targetRevision: <version> # 1.0.*
  helm:
    releaseName: <release_name>
    parameters: []
    values: ""
```

## Dependencies updates

A script is available to help upgrade charts dependencies :

```sh
./ci/scripts/update-charts-dependencies.sh
```

## Template

A [template folder](./template/) is available for easy integration of new chart, to use it follow the steps bellow :

1. Copy the template directory :
    ```sh
    cp -R ./template ./charts/<chart_name>
    ```

2. Update `./charts/<chart_name>/Chart.yaml` and `./charts/<chart_name>/values.yaml` files.

3. Optionally add other services :
    ```sh
    cp -R ./charts/<chart_name>/templates/app ./charts/<chart_name>/templates/<service_name>
    find ./charts/<chart_name>/templates/<service_name> -type f -exec perl -pi -e 's/"app"/"<service_name>"/g' {} \;
    ```
    
    Next, add the appropriate block to the `./charts/<chart_name>/values.yaml` file.

## Contributions

- Each PR is associated with a pipeline that checks the `lint` + `helm-docs`.
- When a merge is performed on the `main` branch, the release pipeline publishes the new version of the chart(s) affected and updates the Helm Repo (`gh-pages` branch).

> [!TIP]  
> The version in the `Chart.yaml` file must be modified before the merge to main, otherwise the release pipeline will error on version duplication.
