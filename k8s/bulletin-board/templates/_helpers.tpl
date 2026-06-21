{{/*
Expand the name of the chart.
*/}}
{{- define "bulletin-board.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "bulletin-board.fullname" -}}
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
Label `app` used by selectors across Deployment, Service, HPA and PDB.
*/}}
{{- define "bulletin-board.appLabel" -}}
{{- .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Target namespace for all resources.
*/}}
{{- define "bulletin-board.namespace" -}}
{{- .Values.namespace.name | default .Release.Namespace }}
{{- end }}

{{/*
ConfigMap name for non-secret application settings.
*/}}
{{- define "bulletin-board.configMapName" -}}
{{- printf "%s-config" (include "bulletin-board.fullname" .) }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "bulletin-board.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "bulletin-board.labels" -}}
helm.sh/chart: {{ include "bulletin-board.chart" . }}
{{ include "bulletin-board.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "bulletin-board.selectorLabels" -}}
app: {{ include "bulletin-board.appLabel" . }}
app.kubernetes.io/name: {{ include "bulletin-board.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "bulletin-board.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "bulletin-board.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}
