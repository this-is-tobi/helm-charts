{{/*
Expand the name of the chart.
*/}}
{{- define "backup-utils.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}


{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "backup-utils.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}


{{/*
Create image pull secret
*/}}
{{- define "backup-utils.imagePullSecret" }}
{{- with .Values.imageCredentials }}
{{- printf "{\"auths\":{\"%s\":{\"username\":\"%s\",\"password\":\"%s\",\"email\":\"%s\",\"auth\":\"%s\"}}}" .registry .username .password .email (printf "%s:%s" .username .password | b64enc) | b64enc }}
{{- end }}
{{- end }}


{{/*
Create container environment variables from configmap
*/}}
{{- define "backup-utils.env" -}}
{{- range $key, $val := .env }}
{{ $key }}: {{ $val | quote }}
{{- end -}}
{{- end }}


{{/*
Create container environment variables from secret
*/}}
{{- define "backup-utils.secret" -}}
{{- range $key, $val := .secrets }}
{{ $key }}: {{ $val | b64enc | quote }}
{{- end }}
{{- end }}


{{/*
Convert a string to kebab-case (lowercase with hyphens)
*/}}
{{- define "backup-utils.toKebabCase" -}}
{{- . | kebabcase }}
{{- end }}


{{/*
Define a file checksum to trigger rollout on configmap of secret change
*/}}
{{- define "backup-utils.checksum" -}}
{{- $ := index . 0 }}
{{- $path := index . 1 }}
{{- $resourceType := include (print $.Template.BasePath $path) $ | fromYaml -}}
{{- if $resourceType -}}
checksum/{{ $resourceType.metadata.name }}: {{ $resourceType.data | toYaml | sha256sum }}
{{- end -}}
{{- end -}}


{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "backup-utils.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}


{{/*
Common labels
*/}}
{{- define "backup-utils.common.labels" -}}
helm.sh/chart: {{ include "backup-utils.chart" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}


{{/*
Selector labels
*/}}
{{- define "backup-utils.selectorLabels" -}}
{{- $root := index . 0 }}
{{- $app := index . 1 -}}
app.kubernetes.io/name: {{ printf "%s-%s" (include "backup-utils.name" $root) (include "backup-utils.toKebabCase" $app) }}
app.kubernetes.io/instance: {{ $root.Release.Name }}
{{- end }}


{{/*
App labels
*/}}
{{- define "backup-utils.labels" -}}
{{- $root := index . 0 }}
{{- $app := index . 1 -}}
{{ include "backup-utils.common.labels" $root }}
{{ include "backup-utils.selectorLabels" (list $root $app) }}
{{- end }}
