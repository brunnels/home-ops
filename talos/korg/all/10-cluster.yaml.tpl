---
apiVersion: v1alpha1
kind: KubeNetworkConfig
podSubnets: [{{ .Data.podCidr }}]
serviceSubnets: [{{ .Data.svcCidr }}]
