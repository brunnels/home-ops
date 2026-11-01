---
apiVersion: v1alpha1
kind: LinkConfig
name: {{ .Data.networkInterface }}
mtu: {{ .Data.mtu }}
{{- with index .Node.Data "vlanIds" }}
{{- range $idx, $item := . }}
---
apiVersion: v1alpha1
kind: VLANConfig
name: {{ $.Data.networkInterface }}.{{ $item.id }}
vlanID: {{ $item.id }}
parent: {{ $.Data.networkInterface }}
mtu: {{ $.Data.mtu }}
{{- if (index $item "address") }}
addresses:
  - address: {{ $item.address }}
{{- end }}
{{- if (index $item "routes") }}
routes:
{{- range $ri, $r := $item.routes }}
  - gateway: {{ index $r "gateway" }}
{{- if (index $r "destination") }}
    destination: {{ index $r "destination" }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
