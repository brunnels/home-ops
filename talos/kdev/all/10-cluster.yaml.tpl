---
apiVersion: v1alpha1
kind: KubeNetworkConfig
podSubnets: [{{ .Data.podCidr }}]
serviceSubnets: [{{ .Data.svcCidr }}]
---
apiVersion: v1alpha1
kind: KubePrismConfig
port: 7445
