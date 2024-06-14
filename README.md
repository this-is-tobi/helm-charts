# Helm charts :anchor:

This repository hosts a set of personal Helm Charts and exposes a Helm Repository on [https://this-is-tobi.github.io/helm-charts](https://this-is-tobi.github.io/helm-charts/index.yaml) thanks to Github Pages and the Github Action [chart releaser](https://github.com/helm/chart-releaser-action).

## Chart list

| Chart                          | Application                               | Description                         |
| ------------------------------ | ----------------------------------------- | ----------------------------------- |
| [charts/dashy](./charts/dashy) | [dashy](https://github.com/lissy93/dashy) | A self-hostable personal dashboard. |

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

## Contribution

- Each PR is associated with a pipeline that checks the `lint` + `helm-docs`.
- When a merge is performed on the `main` branch, the release pipeline publishes the new version of the chart(s) affected and updates the Helm Repo (`gh-pages` branch).

> [!TIP]  
> The version in the `Chart.yaml` file must be modified before the merge to main, otherwise the release pipeline will error on version duplication.
