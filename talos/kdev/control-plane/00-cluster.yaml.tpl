cluster:
  etcd:
    extraArgs:
      listen-metrics-urls: http://0.0.0.0:2381
    advertisedSubnets:
      - {{ .Data.nodeCidr }}
---
# Allow scheduling on control-plane nodes
apiVersion: v1alpha1
kind: KubeNodeConfig
taints:
  node-role.kubernetes.io/control-plane:
    $patch: delete
---
apiVersion: v1alpha1
kind: KubeletConfig
config:
  systemReserved:
    cpu: 500m
    memory: 1Gi
    ephemeral-storage: 2Gi
  kubeReserved:
    cpu: 500m
    memory: 1Gi
    ephemeral-storage: 2Gi
  evictionHard:
    memory.available: 512Mi
    nodefs.available: 10%
    imagefs.available: 15%
  evictionSoft:
    memory.available: 1Gi
  evictionSoftGracePeriod:
    memory.available: 1m
  evictionPressureTransitionPeriod: 30s
---
apiVersion: v1alpha1
kind: KubeAdmissionControlConfig
name: PodSecurity
$patch: delete
---
apiVersion: v1alpha1
kind: KubeAPIServerConfig
extraArgs:
  # https://kubernetes.io/docs/tasks/extend-kubernetes/configure-aggregation-layer/
  enable-aggregator-routing: "true"
---
apiVersion: v1alpha1
kind: KubeControllerManagerConfig
extraArgs:
  bind-address: 0.0.0.0
  feature-gates: HPAScaleToZero=true
---
apiVersion: v1alpha1
kind: KubeCoreDNSConfig
enabled: false
---
# Disable built-in CNI and kube-proxy to use Cilium
apiVersion: v1alpha1
kind: KubeFlannelCNIConfig
$patch: delete
---
apiVersion: v1alpha1
kind: KubeProxyConfig
enabled: false
---
apiVersion: v1alpha1
kind: KubeSchedulerConfig
extraArgs:
  bind-address: 0.0.0.0
config:
  profiles:
    - schedulerName: default-scheduler
      plugins:
        score:
          disabled:
            - name: ImageLocality
      pluginConfig:
        - name: PodTopologySpread
          args:
            defaultingType: List
            defaultConstraints:
              - maxSkew: 1
                topologyKey: kubernetes.io/hostname
                whenUnsatisfiable: ScheduleAnyway
---
apiVersion: v1alpha1
kind: KubeTalosAPIAccessConfig
allowedRoles:
  - os:admin
  - os:reader
allowedKubernetesNamespaces:
  - system-upgrade
  - mcp-system
---
apiVersion: v1alpha1
kind: Layer2VIPConfig
link: {{ .Data.bondName }}.{{ .Data.vipVlan }}
name: {{ .Data.vip }}
