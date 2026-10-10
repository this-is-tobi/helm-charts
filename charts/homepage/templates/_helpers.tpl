{{/*
Expand the name of the chart.
*/}}
{{- define "homepage.name" -}}
{{- .Values.nameOverride | default .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}


{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "homepage.fullname" -}}
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
{{- define "homepage.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}


{{/*
Selector labels.
*/}}
{{- define "homepage.selectorLabels" -}}
app.kubernetes.io/name: {{ include "homepage.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}


{{/*
Common labels.
*/}}
{{- define "homepage.labels" -}}
helm.sh/chart: {{ include "homepage.chart" . }}
{{ include "homepage.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}


{{/*
ServiceAccount name.
*/}}
{{- define "homepage.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- .Values.serviceAccount.name | default (include "homepage.fullname" .) }}
{{- else }}
{{- .Values.serviceAccount.name | default "default" }}
{{- end }}
{{- end }}


{{/*
Homepage image reference; the digest wins over the tag, the tag defaults to appVersion.
*/}}
{{- define "homepage.image" -}}
{{- $ref := printf "%s/%s" .Values.image.registry .Values.image.repository | trimPrefix "/" }}
{{- if .Values.image.digest }}
{{- printf "%s@%s" $ref .Values.image.digest }}
{{- else }}
{{- printf "%s:%s" $ref (.Values.image.tag | default .Chart.AppVersion | toString) }}
{{- end }}
{{- end }}


{{/*
Name of the Secret holding the auth secret, the password and the OIDC client secret.
*/}}
{{- define "homepage.authSecretName" -}}
{{- .Values.auth.secret.existingSecret | default (printf "%s-auth" (include "homepage.fullname" .)) }}
{{- end }}


{{/*
Whether to drop the fixed IDs from the security contexts so that OpenShift assigns them.
*/}}
{{- define "homepage.adaptSecurityContext" -}}
{{- $mode := dig "compatibility" "openshift" "adaptSecurityContext" "auto" (.Values.global | default dict) }}
{{- if or (eq $mode "force") (and (eq $mode "auto") (.Capabilities.APIVersions.Has "security.openshift.io/v1")) }}true{{ end }}
{{- end }}


{{/*
A security context, without runAsUser, runAsGroup and fsGroup when adapting to OpenShift.
Usage: include "homepage.securityContext" (dict "context" .Values.podSecurityContext "root" $)
*/}}
{{- define "homepage.securityContext" -}}
{{- $context := deepCopy (.context | default dict) }}
{{- if include "homepage.adaptSecurityContext" .root }}
{{- $context = omit $context "runAsUser" "runAsGroup" "fsGroup" }}
{{- end }}
{{- with $context }}{{ toYaml . }}{{ end }}
{{- end }}


{{/*
HOMEPAGE_ALLOWED_HOSTS: Homepage answers 400 to a Host header it does not know, so the hosts the chart
exposes it on are allowed, plus allowedHosts for routes created elsewhere. Homepage reads "*" only when
it is the whole value. The host of a wildcard route is no valid entry (Homepage compares them as is).
*/}}
{{- define "homepage.allowedHosts" -}}
{{- if has "*" .Values.allowedHosts }}*
{{- else }}
{{- $hosts := list }}
{{- if .Values.ingress.enabled }}
{{- range .Values.ingress.hosts }}{{ $hosts = append $hosts .name }}{{ end }}
{{- end }}
{{- if .Values.httpRoute.enabled }}
{{- range .Values.httpRoute.hostnames }}{{ if not (hasPrefix "*" .) }}{{ $hosts = append $hosts . }}{{ end }}{{ end }}
{{- end }}
{{- with .Values.auth.externalUrl }}{{ $hosts = append $hosts (urlParse .).host }}{{ end }}
{{- range .Values.allowedHosts }}{{ $hosts = append $hosts . }}{{ end }}
{{- join "," (uniq (compact $hosts)) }}
{{- end }}
{{- end }}


{{/*
Names of the environment variables set in env: the ones the chart would otherwise set itself give way.
*/}}
{{- define "homepage.envNames" -}}
{{- $names := list }}
{{- range .Values.env }}{{ $names = append $names .name }}{{ end }}
{{- toJson $names }}
{{- end }}


{{/*
kubernetes.yaml content: the mode follows kubernetes.enabled unless config.kubernetes sets it.
*/}}
{{- define "homepage.kubernetesConfig" -}}
{{- $config := deepCopy .Values.config.kubernetes }}
{{- if not (hasKey $config "mode") }}
{{- $_ := set $config "mode" (ternary "cluster" "disabled" .Values.kubernetes.enabled) }}
{{- end }}
{{- toYaml $config }}
{{- end }}
