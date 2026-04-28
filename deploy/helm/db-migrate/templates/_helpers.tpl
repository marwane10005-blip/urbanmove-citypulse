{{/* vim: set filetype=mustache: */}}

{{- define "db-migrate.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "db-migrate.fullname" -}}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "db-migrate.labels" -}}
app.kubernetes.io/name: {{ include "db-migrate.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: urbanmove
app.kubernetes.io/component: migration
{{- end -}}

{{- define "db-migrate.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "db-migrate.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}
