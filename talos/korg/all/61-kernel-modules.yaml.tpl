{{- range .Node.Data.kernelModules }}
---
apiVersion: v1alpha1
kind: KernelModuleConfig
name: {{ . }}
{{- if eq . "drbd" }}
parameters:
  - usermode_helper=disabled
{{- end }}
{{- end }}
