---
apiVersion: v1alpha1
kind: UdevRulesConfig
rules:
{{- if index .Node.Data "thunderboltRing" }}
  # Thunderbolt
  - ACTION=="add", SUBSYSTEM=="thunderbolt", ATTR{authorized}=="0", ATTR{authorized}="1"
{{- end }}
  # GPU
  - SUBSYSTEM=="drm", KERNEL=="renderD*", GROUP="44", MODE="0660"
