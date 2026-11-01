---
apiVersion: v1alpha1
kind: ResolverConfig
nameservers:
{{- range .Data.dnsServers }}
  - address: {{ . }}
{{- end }}
searchDomains:
  disableDefault: true
