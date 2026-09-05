{{- define "notes-api.fullname" -}}
{{- .Release.Name -}}
{{- end -}}

{{- define "notes-api.labels" -}}
app.kubernetes.io/name: notes-api
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}
