{{/*
Expand the name of the chart.
*/}}
{{- define "suc.name" -}}
{{- .Values.nameOverride | default .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}


{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "suc.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := .Values.nameOverride | default .Chart.Name }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}


{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "suc.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}


{{/*
Controller name. The controller reads it from its own `upgrade.cattle.io/controller` pod label and
uses it as the leader-election lease name and as the label of every Job it creates, so it is also
the Deployment's only selector: that keeps the selector identical to upstream's manifests, which
lets this chart take over an existing install in place (Deployment selectors are immutable).
*/}}
{{- define "suc.controllerName" -}}
{{- .Values.controllerName | default (include "suc.fullname" .) }}
{{- end }}


{{/*
ServiceAccount name, shared by the controller and (by default) the upgrade Jobs.
*/}}
{{- define "suc.serviceAccountName" -}}
{{- .Values.serviceAccount.name | default (include "suc.fullname" .) }}
{{- end }}


{{/*
Common labels.
*/}}
{{- define "suc.labels" -}}
helm.sh/chart: {{ include "suc.chart" . }}
app.kubernetes.io/name: {{ include "suc.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}


{{/*
Controller image reference; the digest wins over the tag, the tag defaults to appVersion.
*/}}
{{- define "suc.image" -}}
{{- $ref := printf "%s/%s" .Values.image.registry .Values.image.repository | trimPrefix "/" }}
{{- if .Values.image.digest }}
{{- printf "%s@%s" $ref .Values.image.digest }}
{{- else }}
{{- printf "%s:%s" $ref (.Values.image.tag | default .Chart.AppVersion | toString) }}
{{- end }}
{{- end }}


{{/*
Every Plan the release renders, as a list of dicts {name, labels, annotations, spec}. Shared by
templates/plans.yaml, the channel detection behind `caCerts.hostPath: auto` and the validation, so
they can never disagree on what gets rendered. Returned as YAML (`fromYaml` on the caller side).

A Plan spec is layered, lowest to highest: the chart's base (its ServiceAccount, concurrency 1),
`planDefaults`, the fields the k3s preset derives (version/channel, upgrade image, window, the
agent's prepare step), then the plan's own values. Maps deep-merge, lists replace. `enabled`,
`name`, `labels` and `annotations` are metadata keys, never copied into the spec.
The concurrency default matters: the controller treats an unset concurrency as 0, selects no node
and reports the Plan Complete, so a Plan written without it would silently never run.
*/}}
{{- define "suc.plans" -}}
{{- $defaults := deepCopy (.Values.planDefaults | default dict) }}
{{- $base := dict "serviceAccountName" (include "suc.serviceAccountName" .) "concurrency" 1 }}
{{- $plans := list }}
{{- if .Values.k3s.enabled }}
{{- $k3s := .Values.k3s }}
{{- $release := dict "upgrade" (dict "image" $k3s.image) }}
{{- if $k3s.version }}{{ $_ := set $release "version" $k3s.version }}{{ end }}
{{- if $k3s.channel }}{{ $_ := set $release "channel" $k3s.channel }}{{ end }}
{{- if $k3s.window }}{{ $_ := set $release "window" $k3s.window }}{{ end }}
{{- if $k3s.server.enabled }}
{{- $plans = append $plans (dict "name" $k3s.server.name "values" $k3s.server "derived" $release) }}
{{- end }}
{{- if $k3s.agent.enabled }}
{{- $prepare := dict "prepare" (dict "image" $k3s.image "args" (list "prepare" $k3s.server.name)) }}
{{- $plans = append $plans (dict "name" $k3s.agent.name "values" $k3s.agent "derived" (merge $prepare (deepCopy $release))) }}
{{- end }}
{{- end }}
{{- range $name, $plan := .Values.plans }}
{{- if (ne (toString $plan.enabled) "false") }}
{{- $plans = append $plans (dict "name" $name "values" $plan "derived" dict) }}
{{- end }}
{{- end }}
{{- $out := list }}
{{- range $plans }}
{{- $spec := mergeOverwrite (deepCopy $base) (omit $defaults "labels" "annotations" | deepCopy) (deepCopy .derived) (omit .values "enabled" "name" "labels" "annotations" | deepCopy) }}
{{- $labels := mergeOverwrite (deepCopy ($defaults.labels | default dict)) (deepCopy (.values.labels | default dict)) }}
{{- $annotations := mergeOverwrite (deepCopy ($defaults.annotations | default dict)) (deepCopy (.values.annotations | default dict)) }}
{{- $out = append $out (dict "name" .name "labels" $labels "annotations" $annotations "spec" $spec) }}
{{- end }}
{{- dict "plans" $out | toYaml }}
{{- end }}


{{/*
Whether the controller needs the host CA directories: forced on/off, or (auto) only when a
rendered Plan resolves a channel - the controller's only outbound HTTPS call.
*/}}
{{- define "suc.mountHostCACerts" -}}
{{- $mode := toString .Values.caCerts.hostPath }}
{{- if eq $mode "auto" }}
{{- range (include "suc.plans" . | fromYaml).plans }}
{{- if .spec.channel }}true{{ end }}
{{- end }}
{{- else if eq $mode "true" }}true
{{- end }}
{{- end }}
