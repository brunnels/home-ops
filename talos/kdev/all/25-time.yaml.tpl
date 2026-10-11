{{- if (index .Data "ntpServers") }}
---
apiVersion: v1alpha1
kind: TimeSyncConfig
ntp:
  servers:
{{- range .Data.ntpServers }}
    - {{ . }}
{{- end }}
{{- end }}
