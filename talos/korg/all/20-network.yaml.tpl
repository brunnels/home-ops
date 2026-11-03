{{- range .Node.Data.bondInterfaces }}
---
apiVersion: v1alpha1
kind: LinkAliasConfig
name: {{ .name }}
selector:
  match: glob("{{ .macAddr }}", mac(link.hardware_addr))
{{- end }}
---
apiVersion: v1alpha1
kind: BondConfig
name: {{ .Data.bondName }}
links:
{{- range .Node.Data.bondInterfaces }}
  - {{ .name }}
{{- end }}
bondMode: {{ .Data.bondMode }}
mtu: {{ .Data.mtu }}
addresses:
  - address: "{{ .Node.IP }}/24"
routes:
  - gateway: "{{ .Node.Data.gateway }}"
{{- with index .Node.Data "vlans" }}
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
{{- if eq .Node.Role "control-plane" }}
---
apiVersion: v1alpha1
kind: Layer2VIPConfig
link: {{ .Data.bondName }}
name: "{{ .Data.vip }}"
{{- end }}
