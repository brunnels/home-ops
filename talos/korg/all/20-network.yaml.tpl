---
apiVersion: v1alpha1
kind: LinkAliasConfig
name: ethSel0
selector:
  match: glob("{{ .Node.Data.macAddr }}", mac(link.hardware_addr))
---
apiVersion: v1alpha1
kind: BondConfig
name: {{ .Data.bondName }}
links:
  - ethSel0
bondMode: {{ .Data.bondMode }}
mtu: {{ .Data.mtu }}
addresses:
  - address: "{{ .Node.IP }}/24"
routes:
  - gateway: "{{ .Node.Data.gateway }}"
