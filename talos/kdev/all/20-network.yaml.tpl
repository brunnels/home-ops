---
apiVersion: v1alpha1
kind: BondConfig
name: {{ .Data.bondName }}
links:
{{- range .Data.bondInterfaces }}
  - {{ . }}
{{- end }}
bondMode: {{ .Data.bondMode }}
miimon: 100
updelay: 200
downdelay: 200
xmitHashPolicy: layer3+4
lacpRate: fast
mtu: {{ .Data.mtu }}
{{- with index .Node.Data "vlanIds" }}
{{- range $idx, $item := . }}
---
apiVersion: v1alpha1
kind: VLANConfig
name: {{ $.Data.bondName }}.{{ $item.id }}
vlanID: {{ $item.id }}
parent: {{ $.Data.bondName }}
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
