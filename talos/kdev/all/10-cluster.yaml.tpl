---
apiVersion: v1alpha1
kind: KubeNetworkConfig
podSubnets: [{{ .Data.podCidr }}]
serviceSubnets: [{{ .Data.svcCidr }}]
---
apiVersion: v1alpha1
kind: KubePrismConfig
port: 7445
---
apiVersion: v1alpha1
kind: KubeAPIServerConfig
certExtraSANs:
{{- range .Data.certSans }}
    - {{ . }}
{{- end }}
extraArgs:
  # https://kubernetes.io/docs/tasks/extend-kubernetes/configure-aggregation-layer/
  enable-aggregator-routing: "true"
