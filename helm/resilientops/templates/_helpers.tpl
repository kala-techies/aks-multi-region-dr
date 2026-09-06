{{- define "resilientops.fullname" -}}
{{- .Release.Name -}}
{{- end -}}

{{- define "resilientops.labels" -}}
app.kubernetes.io/name: resilientops
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}
