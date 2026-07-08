{{/*
Expand the name of the chart.
*/}}
{{- define "helper.name" -}}
{{- (.Values.nameOverride | default .Chart.Name) | trunc 63 | trimSuffix "-" }}
{{- end }}


{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "helper.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := .Values.nameOverride | default .Chart.Name }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- (printf "%s-%s" .Release.Name $name) | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}


{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "helper.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}


{{/*
Create image pull secret.
*/}}
{{- define "helper.imagePullSecret" }}
{{- $registry := .registry -}}
{{- $username := .username -}}
{{- $password := .password -}}
{{- $email := .email -}}
{{- printf "{\"auths\":{\"%s\":{\"username\":\"%s\",\"password\":\"%s\",\"email\":\"%s\",\"auth\":\"%s\"}}}" $registry $username $password $email (printf "%s:%s" $username $password | b64enc) | b64enc }}
{{- end }}


{{/*Compute the canonical name of an imagePullSecrets entry, falling back to a
generated name so the Secret and the pods referencing it always agree on it.
Parameters:
- root: The root context.
- componentName: The component the entry belongs to ("global" for chart-wide entries).
- index: The index of the entry in its imagePullSecrets list.
- value: The imagePullSecrets entry itself.
*/}}
{{- define "helper.imagePullSecretName" -}}
{{- $root := .root -}}
{{- $componentName := .componentName -}}
{{- $index := .index -}}
{{- $value := .value -}}
{{- $value.name | default (printf "%s-%s-%s-%d" (include "helper.fullname" $root) $componentName "pullsecret" $index) -}}
{{- end -}}


{{/*
Render the imagePullSecrets block of a pod spec, merging global.imagePullSecrets
with the component's own imagePullSecrets so credentials can be declared once
for every component, or scoped to a single one.
Parameters:
- root: The root context.
- componentName: The component the pod spec belongs to.
- componentValues: The component's values map (e.g. .Values.servicename).
*/}}
{{- define "helper.imagePullSecrets" -}}
{{- $root := .root -}}
{{- $componentName := .componentName -}}
{{- $refs := list -}}
{{- range $index, $value := $root.Values.global.imagePullSecrets -}}
{{- $refs = append $refs (include "helper.imagePullSecretName" (dict "root" $root "componentName" "global" "index" $index "value" $value)) -}}
{{- end -}}
{{- range $index, $value := .componentValues.imagePullSecrets -}}
{{- $refs = append $refs (include "helper.imagePullSecretName" (dict "root" $root "componentName" $componentName "index" $index "value" $value)) -}}
{{- end -}}
{{- $refs = $refs | uniq -}}
{{- if $refs }}
imagePullSecrets:
{{- range $refs }}
- name: {{ . }}
{{- end }}
{{- end }}
{{- end -}}


{{/*Create container environment variables with tranform from map to array
*/}}
{{- define "helper.env.map-to-array" -}}
{{- if kindIs "map" . }}
  {{- range $key, $val := . }}
- name: {{ $key }}
    {{- if kindIs "map" $val }}
      {{- toYaml $val | nindent 2 }}
    {{- else }}
  value: {{ $val | quote }}
    {{- end }}
  {{- end }}
{{- else }}
  {{- toYaml . }}
{{- end }}
{{- end }}


{{/*
Merge `global.env` into a component's own `env` before rendering the container env array,
so `global.env` is actually injected into every component's pod template (as originally
intended), not just documented. Both are independently rendered to a plain `- name: ...` env
array first (regardless of whether they're written as a map or a list in values.yaml) and
then concatenated as text, `global.env` first: Kubernetes resolves duplicate env var names by
keeping the LAST occurrence, so the component's own entries correctly take precedence over
`global.env` on conflicting names. If both are unset/empty, renders nothing.
Parameters:
- root: The root context.
- componentEnv: The component's own `env` value (map or array), e.g. .Values.servicename.env.
*/}}
{{- define "helper.componentEnv" -}}
{{- $globalEnv := .root.Values.global.env -}}
{{- $componentEnv := .componentEnv -}}
{{- if $globalEnv }}
{{- include "helper.env.map-to-array" $globalEnv }}
{{- end }}
{{ if $componentEnv }}
{{- include "helper.env.map-to-array" $componentEnv }}
{{- end }}
{{- end -}}


{{/*
Normalize an `envFrom` value (list of configMapRef/secretRef entries - the native Kubernetes
shape - OR a map of arbitrary key -> single entry, so a single entry can be added/overridden/
removed from a values override without repeating the whole list, same rationale as
`extraObjects`) into a plain list.
*/}}
{{- define "helper.envFrom.map-to-array" -}}
{{- if kindIs "map" . }}
  {{- range $key, $val := . }}
- {{- toYaml $val | nindent 2 }}
  {{- end }}
{{- else }}
  {{- toYaml . }}
{{- end }}
{{- end }}


{{/*
Merge `global.envFrom` into a component's own `envFrom` before rendering the container envFrom
array, so `global.envFrom` is actually injected into every component (mirrors `helper.componentEnv`
for `env`). Both are independently normalized to a plain `- configMapRef/secretRef: ...` list
first (regardless of whether they're written as a map or a list in values.yaml) and then
concatenated, `global.envFrom` first: unlike `env`, Kubernetes doesn't dedupe `envFrom` entries
by name, it merges every referenced source, with later sources winning only on individual KEY
collisions - so this ordering (global first, component second) mirrors `env`'s precedence intent
without needing entries to share a name.
Parameters:
- root: The root context.
- componentEnvFrom: The component's own `envFrom` value (map or array), e.g. .Values.servicename.envFrom.
*/}}
{{- define "helper.componentEnvFrom" -}}
{{- $globalEnvFrom := .root.Values.global.envFrom -}}
{{- $componentEnvFrom := .componentEnvFrom -}}
{{- if $globalEnvFrom }}
{{- include "helper.envFrom.map-to-array" $globalEnvFrom }}
{{- end }}
{{ if $componentEnvFrom }}
{{- include "helper.envFrom.map-to-array" $componentEnvFrom }}
{{- end }}
{{- end -}}


{{/*
Create configmap environment variables.
*/}}
{{- define "helper.env" -}}
{{ range $key, $val := . }}
{{ $key }}: {{ tpl (toYaml $val) . | quote }}
{{- end }}
{{- end }}


{{/*
Create secret environment variables.
*/}}
{{- define "helper.secret" -}}
{{ range $key, $val := . }}
{{ $key }}: {{ tpl (toYaml $val) . | b64enc | quote }}
{{- end }}
{{- end }}


{{/*
Define a file checksum to trigger rollout on configmap of secret change.
*/}}
{{- define "helper.checksum" -}}
{{- $ := index . 0 }}
{{- $path := index . 1 }}
{{- $rendered := include (print $.Template.BasePath $path) $ }}
{{- if $rendered }}
{{- $resourceType := $rendered | fromYaml -}}
{{- if and $resourceType $resourceType.kind $resourceType.metadata $resourceType.metadata.name -}}
checksum/{{ $resourceType.kind | lower }}-{{ $resourceType.metadata.name }}: {{ $resourceType.data | toYaml | sha256sum }}
{{- end -}}
{{- end -}}
{{- end -}}


{{/*
Common labels.
*/}}
{{- define "helper.commonLabels" -}}
helm.sh/chart: {{ include "helper.chart" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: {{ include "helper.fullname" . }}
{{- with .Values.commonLabels }}
{{ . | toYaml }}
{{- end }}
{{- end }}


{{/*
Generic selector labels.
Parameters:
- $root: The root context.
- $componentName: The name of the component for which the selector labels are being generated.
*/}}
{{- define "helper.selectorLabels" -}}
{{- $root := .root | default $ -}}
{{- $componentName := .componentName | default "app" -}}
app.kubernetes.io/name: {{ printf "%s-%s" (include "helper.fullname" $root) $componentName | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/instance: {{ $root.Release.Name | trunc 63 | trimSuffix "-" }}
{{- end -}}


{{/*
Generic app labels.
Parameters:
- $root: The root context.
- $componentName: The name of the component for which the selector labels are being generated.
*/}}
{{- define "helper.labels" -}}
{{- $root := .root -}}
{{- $componentName := .componentName | default "app" -}}
{{ include "helper.commonLabels" $root }}
{{ include "helper.selectorLabels" (dict "root" $root "componentName" $componentName) }}
app.kubernetes.io/component: {{ $componentName }}
{{- end -}}


{{/*
Render the pod template (metadata + spec) shared by a `jobs` and `cronjobs` entry.
Both Job and CronJob wrap the exact same PodTemplateSpec, so this is shared to avoid
duplicating it between templates/jobs.yaml and templates/cronjobs.yaml.
Parameters:
- root: The root context.
- name: The job/cronjob name (its key in .Values.jobs / .Values.cronjobs).
- job: The job/cronjob values map.
*/}}
{{- define "helper.job.podTemplate" -}}
{{- $root := .root -}}
{{- $name := .name -}}
{{- $job := .job -}}
{{- $image := $job.image | default dict -}}
{{- $serviceAccount := $job.serviceAccount | default dict -}}
metadata:
  {{- if or $job.podAnnotations $job.envCm $job.envSecret $root.Values.global.envCm $root.Values.global.envSecret }}
  annotations:
    {{- if $job.podAnnotations }}
    {{- toYaml $job.podAnnotations | nindent 4 }}
    {{- end }}
  {{- end }}
  labels: {{- include "helper.labels" (dict "root" $root "componentName" $name) | nindent 4 }}
    {{- if $job.podLabels }}
    {{- toYaml $job.podLabels | nindent 4 }}
    {{- end }}
spec:
  restartPolicy: {{ $job.restartPolicy | default "Never" }}
  {{- include "helper.imagePullSecrets" (dict "root" $root "componentName" $name "componentValues" $job) | nindent 2 }}
  {{- if $serviceAccount.enabled }}
  serviceAccountName: {{ $serviceAccount.name | default (printf "%s-%s" (include "helper.fullname" $root) $name) }}
  {{- end }}
  {{- if $job.podSecurityContext }}
  securityContext: {{- toYaml $job.podSecurityContext | nindent 4 }}
  {{- end }}
  {{- if $job.initContainers }}
  initContainers: {{- tpl (toYaml $job.initContainers) $root | nindent 2 }}
  {{- end }}
  containers:
  - name: {{ $name }}
    {{- if $job.securityContext }}
    securityContext: {{- toYaml $job.securityContext | nindent 6 }}
    {{- end }}
    image: "{{ $root.Values.global.imageRegistry | default $image.registry }}/{{ $image.repository | required (printf "jobs/cronjobs %q is missing image.repository" $name) }}:{{ $image.tag | default $root.Chart.AppVersion }}"
    imagePullPolicy: {{ $image.pullPolicy | default "IfNotPresent" }}
    {{- if $job.command }}
    command:
    {{- range $job.command }}
    - {{ . | quote }}
    {{- end }}
    {{- end }}
    {{- if $job.args }}
    args:
    {{- range $job.args }}
    - {{ . | quote }}
    {{- end }}
    {{- end }}
    {{- if or $job.envCm $root.Values.global.envCm $job.envSecret $root.Values.global.envSecret $job.envFrom $root.Values.global.envFrom }}
    envFrom:
    {{- if or $job.envCm $root.Values.global.envCm }}
    - configMapRef:
        name: {{ printf "%s-%s" (include "helper.fullname" $root) $name }}
    {{- end }}
    {{- if or $job.envSecret $root.Values.global.envSecret }}
    - secretRef:
        name: {{ printf "%s-%s" (include "helper.fullname" $root) $name }}
    {{- end }}
    {{- if or $job.envFrom $root.Values.global.envFrom }}
      {{- include "helper.componentEnvFrom" (dict "root" $root "componentEnvFrom" $job.envFrom) | nindent 4 }}
    {{- end }}
    {{- end }}
    {{- if or $job.env $root.Values.global.env }}
    env: {{- include "helper.componentEnv" (dict "root" $root "componentEnv" $job.env) | nindent 4 }}
    {{- end }}
    {{- if $job.resources }}
    resources: {{- toYaml $job.resources | nindent 6 }}
    {{- end }}
    {{- if or $job.volumeMounts $job.extraVolumeMounts }}
    volumeMounts: {{- toYaml (concat (default (list) $job.volumeMounts) (default (list) $job.extraVolumeMounts)) | nindent 4 }}
    {{- end }}
  {{- if $job.extraContainers }}
    {{- tpl (toYaml $job.extraContainers) $root | nindent 2 }}
  {{- end }}
  {{- if $job.hostAliases }}
  hostAliases: {{- toYaml $job.hostAliases | nindent 2 }}
  {{- end }}
  {{- if $job.nodeSelector }}
  nodeSelector: {{- toYaml $job.nodeSelector | nindent 4 }}
  {{- end }}
  {{- if $job.affinity }}
  affinity: {{- toYaml $job.affinity | nindent 4 }}
  {{- end }}
  {{- if $job.tolerations }}
  tolerations: {{- toYaml $job.tolerations | nindent 2 }}
  {{- end }}
  {{- if or $job.volumes $job.extraVolumes }}
  volumes: {{- tpl (toYaml (concat (default (list) $job.volumes) (default (list) $job.extraVolumes))) $root | nindent 2 }}
  {{- end }}
{{- end -}}


{{/*
Render the pod template (metadata + spec) shared by a Deployment/StatefulSet component
(e.g. `servicename`). Deployment and StatefulSet only differ in a handful of top-level
spec fields (replicas vs. volumeClaimTemplates, serviceName, etc.) - the PodTemplateSpec
they wrap is identical, so it's shared here to avoid maintaining it twice per component
(mirrors `helper.job.podTemplate` above, shared between Job and CronJob).
Parameters:
- root: The root context.
- name: The component name (e.g. "servicename"), used to derive its labels/CM/Secret/
  ServiceAccount name and to locate its configmap.yaml/secret.yaml for checksums.
- component: The component's values map (e.g. .Values.servicename).
*/}}
{{- define "helper.component.podTemplate" -}}
{{- $root := .root -}}
{{- $name := .name -}}
{{- $component := .component -}}
metadata:
  {{- if or $component.podAnnotations $component.envCm $component.envSecret $root.Values.global.envCm $root.Values.global.envSecret }}
  annotations:
    {{- include "helper.checksum" (list $root (printf "/%s/configmap.yaml" $name)) | nindent 4 }}
    {{- include "helper.checksum" (list $root (printf "/%s/secret.yaml" $name)) | nindent 4 }}
    {{- if $component.podAnnotations }}
    {{- toYaml $component.podAnnotations | nindent 4 }}
    {{- end }}
  {{- end }}
  labels: {{- include "helper.labels" (dict "root" $root "componentName" $name) | nindent 4 }}
    {{- if $component.podLabels }}
    {{- toYaml $component.podLabels | nindent 4 }}
    {{- end }}
spec:
  {{- include "helper.imagePullSecrets" (dict "root" $root "componentName" $name "componentValues" $component) | nindent 2 }}
  {{- if $component.serviceAccount.enabled }}
  serviceAccountName: {{ $component.serviceAccount.name | default (printf "%s-%s" (include "helper.fullname" $root) $name | trunc 63 | trimSuffix "-") }}
  {{- end }}
  {{- if $component.podSecurityContext }}
  securityContext: {{- toYaml $component.podSecurityContext | nindent 4 }}
  {{- end }}
  {{- if $component.initContainers }}
  initContainers: {{- tpl (toYaml $component.initContainers) $root | nindent 2 }}
  {{- end }}
  containers:
  - name: {{ $name }}
    {{- if $component.securityContext }}
    securityContext: {{- toYaml $component.securityContext | nindent 6 }}
    {{- end }}
    image: "{{ $root.Values.global.imageRegistry | default $component.image.registry }}/{{ $component.image.repository }}:{{ $component.image.tag | default $root.Chart.AppVersion }}"
    imagePullPolicy: {{ $component.image.pullPolicy }}
    {{- if $component.command }}
    command:
    {{- range $component.command }}
    - {{ . | quote }}
    {{- end }}
    {{- end }}
    {{- if $component.args }}
    args:
    {{- range $component.args }}
    - {{ . | quote }}
    {{- end }}
    {{- end }}
    {{- if or $component.containerPort $component.extraPorts }}
    ports:
    {{- if $component.containerPort }}
    - containerPort: {{ $component.containerPort }}
      name: {{ $component.containerPortName | default "http" }}
      protocol: TCP
    {{- end }}
    {{- if $component.extraPorts }}
      {{- toYaml $component.extraPorts | nindent 4 }}
    {{- end }}
    {{- end }}
    {{- if or $component.envCm $root.Values.global.envCm $component.envSecret $root.Values.global.envSecret $component.envFrom $root.Values.global.envFrom }}
    envFrom:
    {{- if or $component.envCm $root.Values.global.envCm }}
    - configMapRef:
        name: {{ printf "%s-%s" (include "helper.fullname" $root) $name }}
    {{- end }}
    {{- if or $component.envSecret $root.Values.global.envSecret }}
    - secretRef:
        name: {{ printf "%s-%s" (include "helper.fullname" $root) $name }}
    {{- end }}
    {{- if or $component.envFrom $root.Values.global.envFrom }}
      {{- include "helper.componentEnvFrom" (dict "root" $root "componentEnvFrom" $component.envFrom) | nindent 4 }}
    {{- end }}
    {{- end }}
    {{- if or $component.env $root.Values.global.env }}
    env: {{- include "helper.componentEnv" (dict "root" $root "componentEnv" $component.env) | nindent 4 }}
    {{- end }}
    {{- if $component.probes.startupProbe }}
    startupProbe: {{- toYaml $component.probes.startupProbe | nindent 6 }}
    {{- end }}
    {{- if $component.probes.readinessProbe }}
    readinessProbe: {{- toYaml $component.probes.readinessProbe | nindent 6 }}
    {{- end }}
    {{- if $component.probes.livenessProbe }}
    livenessProbe: {{- toYaml $component.probes.livenessProbe | nindent 6 }}
    {{- end }}
    resources: {{- toYaml $component.resources | nindent 6 }}
    {{- if or $component.volumeMounts $component.extraVolumeMounts }}
    volumeMounts: {{- toYaml (concat (default (list) $component.volumeMounts) (default (list) $component.extraVolumeMounts)) | nindent 4 }}
    {{- end }}
  {{- if $component.extraContainers }}
    {{- tpl (toYaml $component.extraContainers) $root | nindent 2 }}
  {{- end }}
  {{- if $component.hostAliases }}
  hostAliases: {{- toYaml $component.hostAliases | nindent 2 }}
  {{- end }}
  {{- if $component.nodeSelector }}
  nodeSelector: {{- toYaml $component.nodeSelector | nindent 4 }}
  {{- end }}
  {{- if $component.affinity }}
  affinity: {{- toYaml $component.affinity | nindent 4 }}
  {{- end }}
  {{- if $component.tolerations }}
  tolerations: {{- toYaml $component.tolerations | nindent 2 }}
  {{- end }}
  {{- if or $component.volumes $component.extraVolumes }}
  volumes: {{- tpl (toYaml (concat (default (list) $component.volumes) (default (list) $component.extraVolumes))) $root | nindent 2 }}
  {{- end }}
{{- end -}}


{{/*
Render a JobSpec (backoffLimit/completions/parallelism/.../template), shared by
templates/jobs.yaml (used directly as `spec:`) and templates/cronjobs.yaml (used as
`spec.jobTemplate.spec:`), since a CronJob's jobTemplate.spec is a regular JobSpec.
Parameters:
- root: The root context.
- name: The job/cronjob name (its key in .Values.jobs / .Values.cronjobs).
- job: The job/cronjob values map.
*/}}
{{- define "helper.job.spec" -}}
{{- $root := .root -}}
{{- $name := .name -}}
{{- $job := .job -}}
{{- if $job.backoffLimit }}
backoffLimit: {{ $job.backoffLimit }}
{{- end }}
{{- if $job.completions }}
completions: {{ $job.completions }}
{{- end }}
parallelism: {{ $job.parallelism | default 1 }}
{{- if $job.activeDeadlineSeconds }}
activeDeadlineSeconds: {{ $job.activeDeadlineSeconds }}
{{- end }}
{{- if $job.ttlSecondsAfterFinished }}
ttlSecondsAfterFinished: {{ $job.ttlSecondsAfterFinished }}
{{- end }}
template:
  {{- include "helper.job.podTemplate" (dict "root" $root "name" $name "job" $job) | nindent 2 }}
{{- end -}}

