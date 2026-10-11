---
apiVersion: v1alpha1
kind: SysctlConfig
params:
{{- range $key, $value := .Data.sysCtls }}
  {{ $key }}: {{ $value }}
{{- end }}
