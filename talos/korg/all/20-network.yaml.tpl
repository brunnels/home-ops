---
apiVersion: v1alpha1
kind: VLANConfig
name: {{ .Data.vlanParent }}.{{ .Data.vlanId }}
parent: {{ .Data.vlanParent }}
vlanID: {{ .Data.vlanId }}
mtu: {{ .Node.Data.mtu }}
addresses:
  - address: {{ .Node.IP }}/{{ .Data.networkPrefix }}
routes:
  - gateway: {{ .Data.gateway }}
{{ if eq .Node.Role "control-plane" -}}
---
apiVersion: v1alpha1
kind: Layer2VIPConfig
link: {{ .Data.vlanParent }}.{{ .Data.vlanId }}
name: {{ .Data.vip }}
{{ end -}}
---
machine:
  network:
    interfaces:
      - interface: {{ .Data.vlanParent }}
        mtu: {{ .Node.Data.mtu }}
