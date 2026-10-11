{{- if index .Node.Data "thunderboltRing" }}
{{- with index .Node.Data "thunderboltRing" }}
{{- range $idx, $item := . }}
---
apiVersion: v1alpha1
kind: LinkAliasConfig
name: {{ $item.name }}
selector:
  match: link.bus_path == "{{ $item.busPath }}"
---
apiVersion: v1alpha1
kind: LinkConfig
name: {{ $item.name }}
up: true
mtu: 65520
addresses:
  - address: {{ $item.addr }}
routes:
  - destination: {{ $item.destination }}
    metric: 2048
  - destination: {{ if eq $idx 0 }}{{ (index $.Node.Data.thunderboltRing 1).destination }}{{ else }}{{ (index $.Node.Data.thunderboltRing 0).destination }}{{ end }}
    gateway: {{ $item.destination | trimSuffix "/32" }}
    metric: 4096
---
{{- end }}
{{- end }}
{{- end }}
