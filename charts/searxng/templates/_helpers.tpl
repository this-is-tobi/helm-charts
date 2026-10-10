{{/*
Expand the name of the chart.
*/}}
{{- define "searxng.name" -}}
{{- .Values.nameOverride | default .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}


{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "searxng.fullname" -}}
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
{{- define "searxng.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}


{{/*
Selector labels.
*/}}
{{- define "searxng.selectorLabels" -}}
app.kubernetes.io/name: {{ include "searxng.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}


{{/*
Common labels.
*/}}
{{- define "searxng.labels" -}}
helm.sh/chart: {{ include "searxng.chart" . }}
{{ include "searxng.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}


{{/*
ServiceAccount name.
*/}}
{{- define "searxng.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- .Values.serviceAccount.name | default (include "searxng.fullname" .) }}
{{- else }}
{{- .Values.serviceAccount.name | default "default" }}
{{- end }}
{{- end }}


{{/*
SearXNG image reference; the digest wins over the tag, the tag defaults to appVersion.
*/}}
{{- define "searxng.image" -}}
{{- $ref := printf "%s/%s" .Values.image.registry .Values.image.repository | trimPrefix "/" }}
{{- if .Values.image.digest }}
{{- printf "%s@%s" $ref .Values.image.digest }}
{{- else }}
{{- printf "%s:%s" $ref (.Values.image.tag | default .Chart.AppVersion | toString) }}
{{- end }}
{{- end }}


{{/*
Name of the Secret holding the SearXNG secret key.
*/}}
{{- define "searxng.secretName" -}}
{{- .Values.secret.existingSecret | default (include "searxng.fullname" .) }}
{{- end }}


{{/*
Service of the valkey subchart: the name its fullname helper gives it (also the name of its Secret).
*/}}
{{- define "searxng.valkeyHost" -}}
{{- if .Values.valkey.fullnameOverride }}
{{- .Values.valkey.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := .Values.valkey.nameOverride | default "valkey" }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}


{{/*
Port of the valkey subchart's service.
*/}}
{{- define "searxng.valkeyPort" -}}
{{- dig "service" "port" 6379 .Values.valkey }}
{{- end }}


{{/*
Secret and key of the Valkey password: the subchart's own Secret unless valkey.auth.existingSecret is set.
*/}}
{{- define "searxng.valkeySecretName" -}}
{{- with dig "auth" "existingSecret" "" .Values.valkey }}{{ tpl . $ }}{{ else }}{{ include "searxng.valkeyHost" . }}{{ end }}
{{- end }}

{{- define "searxng.valkeyPasswordKey" -}}
{{- if dig "auth" "existingSecret" "" .Values.valkey }}{{ dig "auth" "existingSecretPasswordKey" "password" .Values.valkey }}{{ else }}password{{ end }}
{{- end }}


{{/*
SEARXNG_VALKEY_URL: the subchart's service, with the password Kubernetes expands from VALKEY_PASSWORD.
*/}}
{{- define "searxng.valkeyUrl" -}}
{{- $credentials := ternary ":$(VALKEY_PASSWORD)@" "" (dig "auth" "enabled" true .Values.valkey) }}
{{- printf "valkey://%s%s:%s/0" $credentials (include "searxng.valkeyHost" .) (include "searxng.valkeyPort" .) }}
{{- end }}


{{/*
settings.yml content, always with use_default_settings: without it SearXNG takes the file as its
complete settings and fails on every setting left out.
*/}}
{{- define "searxng.settings" -}}
{{- $settings := deepCopy .Values.settings }}
{{- if not (hasKey $settings "use_default_settings") }}
{{- $_ := set $settings "use_default_settings" true }}
{{- end }}
{{- toYaml $settings }}
{{- end }}


{{/*
Whether to drop the fixed IDs from the security contexts so that OpenShift assigns them.
*/}}
{{- define "searxng.adaptSecurityContext" -}}
{{- $mode := dig "compatibility" "openshift" "adaptSecurityContext" "auto" (.Values.global | default dict) }}
{{- if or (eq $mode "force") (and (eq $mode "auto") (.Capabilities.APIVersions.Has "security.openshift.io/v1")) }}true{{ end }}
{{- end }}


{{/*
A security context, without runAsUser, runAsGroup and fsGroup when adapting to OpenShift.
Usage: include "searxng.securityContext" (dict "context" .Values.podSecurityContext "root" $)
*/}}
{{- define "searxng.securityContext" -}}
{{- $context := deepCopy (.context | default dict) }}
{{- if include "searxng.adaptSecurityContext" .root }}
{{- $context = omit $context "runAsUser" "runAsGroup" "fsGroup" }}
{{- end }}
{{- with $context }}{{ toYaml . }}{{ end }}
{{- end }}
