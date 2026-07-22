{{/*
Expand the name of the chart.
*/}}
{{- define "template.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}


{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "template.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}


{{/*
Create image pull secret
*/}}
{{- define "template.imagePullSecret" }}
{{- with .Values.imageCredentials }}
{{- printf "{\"auths\":{\"%s\":{\"username\":\"%s\",\"password\":\"%s\",\"email\":\"%s\",\"auth\":\"%s\"}}}" .registry .username .password .email (printf "%s:%s" .username .password | b64enc) | b64enc }}
{{- end }}
{{- end }}


{{/*
Create container environment variables from configmap
*/}}
{{- define "template.env" -}}
{{ range $key, $val := .env }}
{{ $key }}: {{ $val | quote }}
{{- end }}
{{- end }}


{{/*
Create container environment variables from secret
*/}}
{{- define "template.secret" -}}
{{ range $key, $val := .secrets }}
{{ $key }}: {{ $val | b64enc | quote }}
{{- end }}
{{- end }}


{{/*
Define a file checksum to trigger rollout on configmap of secret change
*/}}
{{- define "checksum" -}}
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
{{- define "template.fullname" -}}
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
{{- define "template.common.labels" -}}
helm.sh/chart: {{ include "template.chart" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}


{{/*
Selector labels
*/}}
{{- define "template.selectorLabels" -}}
app.kubernetes.io/name: {{ include "template.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}


{{/*
Labels
*/}}
{{- define "template.labels" -}}
{{ include "template.common.labels" . }}
{{ include "template.selectorLabels" . }}
{{- if .Values.labels }}
{{ range $key, $val := .Values.labels }}
{{- $key }}: {{ $val }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Determine credentials management mode:
- "operator": CNPG operator auto-generates secrets (default, stable across upgrades)
- "chart": Helm chart creates secrets from provided password values
- "external": User-managed pre-existing secrets
*/}}
{{- define "template.credentialsMode" -}}
{{- if .Values.credentials.existingSecrets.enabled -}}
external
{{- else if or .Values.credentials.password .Values.credentials.postgresPassword -}}
chart
{{- else -}}
operator
{{- end -}}
{{- end -}}

{{/*
Barman object store configuration for the backup store.
Shared between the plugin ObjectStore CR (spec.configuration) and the legacy in-tree barmanObjectStore.
*/}}
{{- define "template.backup.storeConfiguration" -}}
destinationPath: {{ .Values.backup.destinationPath }}
endpointURL: {{ .Values.backup.endpointURL }}
{{- if or .Values.backup.endpointCA.create .Values.backup.endpointCA.secretName }}
endpointCA:
  name: {{ .Values.backup.endpointCA.secretName | default (printf "%s-%s" (include "template.fullname" .) "backup-ca") }}
  key: {{ .Values.backup.endpointCA.key }}
{{- end }}
s3Credentials:
  accessKeyId:
    name: {{ .Values.backup.s3Credentials.secretName | default (printf "%s-%s" (include "template.fullname" .) "backup-creds") }}
    key: {{ .Values.backup.s3Credentials.accessKeyId.key }}
  secretAccessKey:
    name: {{ .Values.backup.s3Credentials.secretName | default (printf "%s-%s" (include "template.fullname" .) "backup-creds") }}
    key: {{ .Values.backup.s3Credentials.secretAccessKey.key }}
  region:
    name: {{ .Values.backup.s3Credentials.secretName | default (printf "%s-%s" (include "template.fullname" .) "backup-creds") }}
    key: {{ .Values.backup.s3Credentials.region.key }}
{{- if or .Values.backup.compression .Values.backup.encryption .Values.backup.jobs .Values.backup.dataAdditionalCommandArgs }}
data:
  {{- if .Values.backup.compression }}
  compression: {{ .Values.backup.compression }}
  {{- end }}
  {{- if .Values.backup.encryption }}
  encryption: {{ .Values.backup.encryption }}
  {{- end }}
  {{- if .Values.backup.jobs }}
  jobs: {{ .Values.backup.jobs }}
  {{- end }}
  {{- if .Values.backup.dataAdditionalCommandArgs }}
  additionalCommandArgs: {{- toYaml .Values.backup.dataAdditionalCommandArgs | nindent 2 }}
  {{- end }}
{{- end }}
{{- if or .Values.backup.compression .Values.backup.encryption .Values.backup.maxParallel .Values.backup.walAdditionalCommandArgs }}
wal:
  {{- if .Values.backup.compression }}
  compression: {{ .Values.backup.compression }}
  {{- end }}
  {{- if .Values.backup.encryption }}
  encryption: {{ .Values.backup.encryption }}
  {{- end }}
  {{- if .Values.backup.maxParallel }}
  maxParallel: {{ .Values.backup.maxParallel }}
  {{- end }}
  {{- if .Values.backup.walAdditionalCommandArgs }}
  additionalCommandArgs: {{- toYaml .Values.backup.walAdditionalCommandArgs | nindent 2 }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Barman object store configuration for the recovery store (with fallback to backup settings).
Shared between the plugin ObjectStore CR (spec.configuration) and the legacy in-tree barmanObjectStore.
*/}}
{{- define "template.recovery.storeConfiguration" -}}
destinationPath: {{ .Values.recovery.destinationPath | default .Values.backup.destinationPath }}
endpointURL: {{ .Values.recovery.endpointURL | default .Values.backup.endpointURL }}
{{- $useRecoveryCA := or .Values.recovery.endpointCA.create .Values.recovery.endpointCA.secretName }}
{{- $useBackupCA := or .Values.backup.endpointCA.create .Values.backup.endpointCA.secretName }}
{{- if or $useRecoveryCA $useBackupCA }}
endpointCA:
  {{- if $useRecoveryCA }}
  name: {{ .Values.recovery.endpointCA.secretName | default (printf "%s-%s" (include "template.fullname" .) "recovery-ca") }}
  key: {{ .Values.recovery.endpointCA.key }}
  {{- else }}
  name: {{ .Values.backup.endpointCA.secretName | default (printf "%s-%s" (include "template.fullname" .) "backup-ca") }}
  key: {{ .Values.backup.endpointCA.key }}
  {{- end }}
{{- end }}
{{- $useRecoveryCreds := or .Values.recovery.s3Credentials.create .Values.recovery.s3Credentials.secretName }}
s3Credentials:
  accessKeyId:
    {{- if $useRecoveryCreds }}
    name: {{ .Values.recovery.s3Credentials.secretName | default (printf "%s-%s" (include "template.fullname" .) "recovery-creds") }}
    key: {{ .Values.recovery.s3Credentials.accessKeyId.key }}
    {{- else }}
    name: {{ .Values.backup.s3Credentials.secretName | default (printf "%s-%s" (include "template.fullname" .) "backup-creds") }}
    key: {{ .Values.backup.s3Credentials.accessKeyId.key }}
    {{- end }}
  secretAccessKey:
    {{- if $useRecoveryCreds }}
    name: {{ .Values.recovery.s3Credentials.secretName | default (printf "%s-%s" (include "template.fullname" .) "recovery-creds") }}
    key: {{ .Values.recovery.s3Credentials.secretAccessKey.key }}
    {{- else }}
    name: {{ .Values.backup.s3Credentials.secretName | default (printf "%s-%s" (include "template.fullname" .) "backup-creds") }}
    key: {{ .Values.backup.s3Credentials.secretAccessKey.key }}
    {{- end }}
  region:
    {{- if $useRecoveryCreds }}
    name: {{ .Values.recovery.s3Credentials.secretName | default (printf "%s-%s" (include "template.fullname" .) "recovery-creds") }}
    key: {{ .Values.recovery.s3Credentials.region.key }}
    {{- else }}
    name: {{ .Values.backup.s3Credentials.secretName | default (printf "%s-%s" (include "template.fullname" .) "backup-creds") }}
    key: {{ .Values.backup.s3Credentials.region.key }}
    {{- end }}
{{- end }}

{{/*
Barman object store configuration for the replica store.
Shared between the plugin ObjectStore CR (spec.configuration) and the legacy in-tree barmanObjectStore.
*/}}
{{- define "template.replica.storeConfiguration" -}}
destinationPath: {{ .Values.replica.destinationPath }}
endpointURL: {{ .Values.replica.endpointURL }}
{{- if or .Values.replica.endpointCA.create .Values.replica.endpointCA.secretName }}
endpointCA:
  name: {{ .Values.replica.endpointCA.secretName | default (printf "%s-%s" (include "template.fullname" .) "replica-ca") }}
  key: {{ .Values.replica.endpointCA.key }}
{{- end }}
s3Credentials:
  accessKeyId:
    name: {{ .Values.replica.s3Credentials.secretName | default (printf "%s-%s" (include "template.fullname" .) "replica-creds") }}
    key: {{ .Values.replica.s3Credentials.accessKeyId.key }}
  secretAccessKey:
    name: {{ .Values.replica.s3Credentials.secretName | default (printf "%s-%s" (include "template.fullname" .) "replica-creds") }}
    key: {{ .Values.replica.s3Credentials.secretAccessKey.key }}
  region:
    name: {{ .Values.replica.s3Credentials.secretName | default (printf "%s-%s" (include "template.fullname" .) "replica-creds") }}
    key: {{ .Values.replica.s3Credentials.region.key }}
{{- end }}

{{/*
Render a barman store configuration with extra fields deep-merged on top (extra fields win, lists are replaced).
Usage: include "template.mergedStoreConfiguration" (list . "template.backup.storeConfiguration" .Values.backup.extraConfiguration)
*/}}
{{- define "template.mergedStoreConfiguration" -}}
{{- $ctx := index . 0 }}
{{- $config := include (index . 1) $ctx | fromYaml }}
{{- with index . 2 }}
{{- $config = mergeOverwrite $config (deepCopy .) }}
{{- end }}
{{- toYaml $config }}
{{- end }}

{{/*
DEPRECATED: Legacy backup configuration using in-tree barmanObjectStore.
This template will be removed in a future version when CloudNativePG drops support for the in-tree method.
Only use this when backup.legacyMode is explicitly set to true.
*/}}
{{- define "template.legacy.backup" -}}
{{- if and .Values.backup.enabled .Values.backup.legacyMode (ne .Values.mode "recovery") }}
backup:
  barmanObjectStore: {{- include "template.mergedStoreConfiguration" (list . "template.backup.storeConfiguration" .Values.backup.extraConfiguration) | nindent 4 }}
  retentionPolicy: {{ .Values.backup.retentionPolicy }}
{{- end }}
{{- end }}
