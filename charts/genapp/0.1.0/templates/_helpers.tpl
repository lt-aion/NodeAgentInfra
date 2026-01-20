{{/*
Expand the name of the chart.
*/}}
{{- define "genapp.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "genapp.fullname" -}}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "genapp.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "genapp.labels" -}}
helm.sh/chart: {{ include "genapp.chart" . }}
{{ include "genapp.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "genapp.selectorLabels" -}}
app.kubernetes.io/name: {{ include "genapp.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "genapp.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "genapp.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Check if any container has any service ports defined.
*/}}
{{- define "genapp.service.hasPorts" -}}
{{- range .Values.containers -}}
  {{- if and .ports (or .ports.http .ports.grpc .ports.metrics .ports.additional) -}}
true
  {{- end -}}
{{- end -}}
{{- end -}}

{{/*
Check if any container has a metrics port defined.
*/}}
{{- define "genapp.servicemonitor.hasMetricsPorts" -}}
{{- range .Values.containers -}}
  {{- if and .ports .ports.metrics -}}
true
  {{- end -}}
{{- end -}}
{{- end -}}
