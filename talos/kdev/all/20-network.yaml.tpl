machine:
  network:
    interfaces:
      - interface: {{ .Data.bondName }}
        mtu: {{ .Node.Data.mtu }}
        bond:
          mode: {{ .Data.bondMode }}
          lacpRate: fast
          xmitHashPolicy: layer3+4
          miimon: 100
          updelay: 200
          downdelay: 200
          interfaces:
            {{- range .Node.Data.bondInterfaces }}
            - {{ . }}
            {{- end }}
        vlans:
          - vlanId: {{ .Data.vlanId }}
            mtu: {{ .Node.Data.mtu }}
            addresses: [{{ .Node.IP }}/{{ .Data.networkPrefix }}]
            routes:
              - network: 0.0.0.0/0
                gateway: {{ .Data.gateway }}
      - interface: eth0
        dhcp: false
      - interface: eth1
        dhcp: false
      - deviceSelector:
          busPath: {{ .Node.Data.tb_next.busPath }}
        dhcp: false
        mtu: 65520
        addresses: [{{ .Node.Data.tb_next.addr }}]
        routes:
          - network: {{ .Node.Data.tb_next.route }}
            metric: {{ .Node.Data.tb_next.metric }}
      - deviceSelector:
          busPath: {{ .Node.Data.tb_prev.busPath }}
        dhcp: false
        mtu: 65520
        addresses: [{{ .Node.Data.tb_prev.addr }}]
        routes:
          - network: {{ .Node.Data.tb_prev.route }}
            metric: {{ .Node.Data.tb_prev.metric }}
{{ if eq .Node.Role "control-plane" -}}
---
apiVersion: v1alpha1
kind: Layer2VIPConfig
link: {{ .Data.bondName }}.{{ .Data.vlanId }}
name: {{ .Data.vip }}
{{ end -}}
