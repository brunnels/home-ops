---
apiVersion: v1alpha1
kind: KubeletConfig
config:
  crashLoopBackOff:
    maxContainerRestartPeriod: 60s
  imageMaximumGCAge: 168h
  imageGCHighThresholdPercent: 70
  imageGCLowThresholdPercent: 65
  maxParallelImagePulls: 3
  maxPods: 150
  serializeImagePulls: false
  shutdownGracePeriod: 120s
  shutdownGracePeriodCriticalPods: 60s
---
apiVersion: v1alpha1
kind: KubeNodeConfig
nodeIP:
  validSubnets:
    - {{ .Data.nodeCidr }}
labels:
  intel.feature.node.kubernetes.io/gpu: "true"
{{- if (index .Node.Data "thunderboltRing") }}
  miroir.home-operations.com/address: "{{ (index .Node.Data.thunderboltRing 0).addr | trimSuffix "/32" }}"
{{- end }}
