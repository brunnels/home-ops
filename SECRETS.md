# Secrets.md: Akeyless Configuration for home-ops

This guide documents all secrets that must be created in Akeyless for the home-ops Kubernetes GitOps infrastructure.

**Akeyless Paths Pattern:**

- Cluster-specific: `CLUSTER-cluster/KEY_NAME` (e.g., `kdev-cluster/SECRET_DOMAIN`)
- App-specific: `CLUSTER/APP_NAME` (e.g., `kdev/cloudflare`)
- Shared (non-cluster-prefixed): `qnap`, `github`, `huggingface`

## Global Akeyless Secrets (Shared - Not Cluster-Specific)

These secrets are shared across all clusters and must be created once.

### akeyless (Akeyless API Credentials)

**Path:** `akeyless`

Used by external-secrets to authenticate with Akeyless vault.

**Required Keys:**

- `ACCESS_ID` - Akeyless API access ID
- `ACCESS_TYPE_PARAM` - Akeyless API access key/secret

**Reference:** `kubernetes/base/external-secrets-stores/akeyless/externalsecret.yaml`

### github (GitHub Webhooks & Notifications)

**Path:** `github`

GitHub tokens for Flux webhook integration and status notifications.

**Required Keys:**

- `GITHUB_WEBHOOK_TOKEN` - Flux webhook token for Git push reconciliation
- `GITHUB_NOTIFICATION_TOKEN` - GitHub token for deployment status updates

**Reference:**

- `kubernetes/base/flux-system/flux-instance/externalsecret.yaml`
- `kubernetes/components/common/alerts/github-status/externalsecret.yaml`

### huggingface (HuggingFace Model Access)

**Path:** `huggingface`

HuggingFace token for accessing gated models (LLMs, embeddings).

**Required Keys:**

- `HF_TOKEN` - HuggingFace API token for model downloads/access

**Reference:**

- `kubernetes/base/ai/vllm-stack/externalsecret.yaml`
- `kubernetes/base/ai/open-webui/externalsecret.yaml`

### qnap (NAS Storage Configuration)

**Path:** `qnap`

Configuration for accessing QNAP NAS for backups, S3 storage, and media.

**Required Keys:**

- `QNAP_URL` - QNAP NAS S3 endpoint (e.g., `s3.qnap.example.com`)
- `QNAP_HOSTNAME` - QNAP hostname/IP for NFS/SMB mounts
- `S3_KEY_ID` - QNAP S3 access key
- `S3_SECRET_KEY` - QNAP S3 secret key

**Reference:**

- `kubernetes/components/volsync/externalsecret.yaml`
- `kubernetes/base/database/pgo-cluster/externalsecret.yaml`

## Cluster-Specific Secrets (Per-Cluster: kdev or korg)

These secrets MUST be created for EACH cluster (kdev and korg).

### CLUSTER-cluster (Cluster-Wide Settings)

**Path:** `CLUSTER-cluster` (e.g., `kdev-cluster`, `korg-cluster`)

Global configuration applied to all apps in the cluster. Created during bootstrap.

**Required Keys:**

- `SECRET_DOMAIN` - Primary domain for cluster (e.g., `kraven.org`)
- `INTERNAL_DOMAIN` - Internal-only domain (e.g., `kraven.local`)
- `LDAP_BASE_DN` - LDAP base DN for user authentication (e.g., `dc=kraven,dc=org`)
- `QNAP_HOSTNAME` - NAS hostname (same as global qnap secret key)
- `CLOUDFLARE_TUNNEL_ID` - Cloudflare tunnel ID for ingress

**Reference:**

- `kubernetes/components/common/cluster-secrets/externalsecret.yaml` (loaded as ConfigMap + Secret)
- `bootstrap/cluster-secrets.yaml` (initial Secret during bootstrap)

### CLUSTER/cloudflare (Cloudflare DNS & Tunnel)

**Path:** `CLUSTER/cloudflare` (e.g., `kdev/cloudflare`, `korg/cloudflare`)

Cloudflare credentials for DNS management and tunnel authentication.

**Required Keys:**

- `CF_API_TOKEN` - Cloudflare API token (with DNS/zone edit permissions)
- `CF_ZONE_ID` - Cloudflare zone ID for primary domain
- `CF_TUNNEL_TOKEN` - Cloudflare Tunnel token for ingress

**Reference:**

- `kubernetes/base/cert-manager/externalsecret.yaml`
- `kubernetes/base/network/cloudflare-dns/externalsecret.yaml`
- `kubernetes/base/network/cloudflare-tunnel/externalsecret.yaml`

### CLUSTER/production-tls (TLS Certificate)

**Path:** `CLUSTER/production-tls` (e.g., `kdev/production-tls`, `korg/production-tls`)

Wildcard TLS certificate for the cluster's primary domain (base64-encoded PEM).

**Required Keys (Base64-encoded):**

- `tls.crt` - TLS certificate (PEM format, base64)
- `tls.key` - TLS private key (PEM format, base64)

**Reference:** `kubernetes/base/network/envoy-gateway/externalsecret.yaml`

**Note:** Should be a wildcard cert covering `*.${SECRET_DOMAIN}` and `${SECRET_DOMAIN}`

### CLUSTER/weave-gitops (Weave GitOps OIDC)

**Path:** `CLUSTER/weave-gitops` (e.g., `kdev/weave-gitops`, `korg/weave-gitops`)

OIDC client credentials for Weave GitOps web UI authentication.

**Required Keys:**

- `WEAVE_OIDC_CLIENT_ID` - OIDC client ID for Weave GitOps
- `WEAVE_OIDC_CLIENT_SECRET` - OIDC client secret

**Reference:** `kubernetes/base/flux-system/weave-gitops/externalsecret.yaml`

### CLUSTER/pgo (PostgreSQL Operator Backup)

**Path:** `CLUSTER/pgo` (e.g., `kdev/pgo`, `korg/pgo`)

PostgreSQL backup encryption and S3 storage credentials.

**Required Keys:**

- `S3_KEY_ID` - S3/QNAP access key for backups
- `S3_SECRET_KEY` - S3/QNAP secret key
- `POSTGRES_BACKUP_CIPHER_PASS` - Encryption passphrase for backups

**Reference:** `kubernetes/base/database/pgo-cluster/externalsecret.yaml`

### CLUSTER/pgadmin (PGAdmin OIDC)

**Path:** `CLUSTER/pgadmin` (e.g., `kdev/pgadmin`, `korg/pgadmin`)

OIDC configuration for PGAdmin web UI single sign-on.

**Required Keys:**

- `PGADMIN_OIDC_CLIENT_ID` - OIDC client ID
- `PGADMIN_OIDC_CLIENT_SECRET` - OIDC client secret

**Reference:** `kubernetes/base/database/pgo-cluster/externalsecret.yaml`

### CLUSTER/grafana (Grafana Observability)

**Path:** `CLUSTER/grafana` (e.g., `kdev/grafana`, `korg/grafana`)

Grafana admin credentials and OIDC integration.

**Required Keys:**

- `GRAFANA_ADMIN_USERNAME` - Grafana admin username
- `GRAFANA_ADMIN_PASSWORD` - Grafana admin password
- `GRAFANA_OIDC_CLIENT_ID` - OIDC client ID for SSO
- `GRAFANA_OIDC_CLIENT_SECRET` - OIDC client secret

**Reference:** `kubernetes/base/observability/grafana-operator/externalsecret.yaml`

### CLUSTER/kopia (Backup & Restore)

**Path:** `CLUSTER/kopia` (e.g., `kdev/kopia`, `korg/kopia`)

Kopia backup tool encryption and credentials.

**Required Keys:**

- `KOPIA_PASSWORD` - Master encryption password for Kopia backups

**Reference:** `kubernetes/components/kopiur/secret/externalsecret.yaml`

### CLUSTER/volsync (Volume Synchronization)

**Path:** `CLUSTER/volsync` (e.g., `kdev/volsync`, `korg/volsync`)

Restic backup tool configuration for persistent volume replication.

**Required Keys:**

- `QNAP_URL` - QNAP S3 endpoint for backups
- `VOLSYNC_S3_BUCKET` - S3 bucket name for volumes
- `RESTIC_PASSWORD` - Restic backup encryption password
- `S3_KEY_ID` - S3 access key
- `S3_SECRET_KEY` - S3 secret key

**Reference:** `kubernetes/components/volsync/externalsecret.yaml`

## Media & Download Applications (Cluster-Specific)

These application-specific secrets are created for each cluster.

### CLUSTER/cloudflare (Cloudflare - Also used by Media)

_See above - same secret as network_

### CLUSTER/open-webui (Open WebUI - LLM Chat Interface)

**Path:** `CLUSTER/open-webui` (e.g., `kdev/open-webui`, `korg/open-webui`)

OpenWebUI authentication and database configuration.

**Required Keys:**

- `OPEN_WEBUI_OIDC_CLIENT_ID` - OIDC client ID
- `OPEN_WEBUI_OIDC_CLIENT_SECRET` - OIDC client secret
- `OPEN_WEBUI_SECRET_KEY` - Session encryption key

**Reference:** `kubernetes/base/ai/open-webui/externalsecret.yaml`

**Note:** Also pulls from `huggingface` secret and database secret from namespace secrets store

### CLUSTER/sabnzbd (SABnzbd - Usenet Downloader)

**Path:** `CLUSTER/sabnzbd` (e.g., `kdev/sabnzbd`, `korg/sabnzbd`)

SABnzbd API keys for download management.

**Required Keys:**

- `SABNZBD_API_KEY` - SABnzbd API key for automation
- `SABNZBD_NZB_KEY` - SABnzbd NZB key for security

**Reference:** `kubernetes/base/downloads/sabnzbd/externalsecret.yaml`

### CLUSTER/sonarr (Sonarr - TV Series Automation)

**Path:** `CLUSTER/sonarr` (e.g., `kdev/sonarr`, `korg/sonarr`)

Sonarr API key for TV show management.

**Required Keys:**

- `SONARR_API_KEY` - Sonarr API key for automation/webhooks

**Reference:** `kubernetes/base/downloads/sonarr/externalsecret.yaml`

### CLUSTER/radarr (Radarr - Movie Automation)

**Path:** `CLUSTER/radarr` (e.g., `kdev/radarr`, `korg/radarr`)

Radarr API key for movie management.

**Required Keys:**

- `RADARR_API_KEY` - Radarr API key for automation/webhooks

**Reference:** `kubernetes/base/downloads/radarr/externalsecret.yaml` (if using)

### CLUSTER/readarr (Readarr - Book Automation)

**Path:** `CLUSTER/readarr` (e.g., `kdev/readarr`, `korg/readarr`)

Readarr API key for book management.

**Required Keys:**

- `READARR_API_KEY` - Readarr API key for automation/webhooks

**Reference:** `kubernetes/base/downloads/readarr/externalsecret.yaml`

### CLUSTER/lidarr (Lidarr - Music Automation)

**Path:** `CLUSTER/lidarr` (e.g., `kdev/lidarr`, `korg/lidarr`)

Lidarr API key for music management.

**Required Keys:**

- `LIDARR_API_KEY` - Lidarr API key for automation/webhooks

**Reference:** `kubernetes/base/downloads/lidarr/externalsecret.yaml`

### CLUSTER/prowlarr (Prowlarr - Indexer Aggregation)

**Path:** `CLUSTER/prowlarr` (e.g., `kdev/prowlarr`, `korg/prowlarr`)

Prowlarr API key for torrent/usenet indexer management.

**Required Keys:**

- `PROWLARR_API_KEY` - Prowlarr API key for automation

**Reference:** `kubernetes/base/downloads/prowlarr/externalsecret.yaml`

### CLUSTER/igdb (IGDB - Video Game Database)

**Path:** `CLUSTER/igdb` (e.g., `kdev/igdb`, `korg/igdb`)

IGDB API credentials for game metadata in ROMM.

**Required Keys:**

- `IGDB_CLIENT_ID` - IGDB API client ID
- `IGDB_CLIENT_SECRET` - IGDB API client secret

**Reference:** `kubernetes/base/downloads/romm/externalsecret.yaml`

### CLUSTER/romm (ROMM - ROM Manager)

**Path:** `CLUSTER/romm` (e.g., `kdev/romm`, `korg/romm`)

ROMM application configuration and authentication.

**Required Keys:**

- `ROMM_OIDC_CLIENT_ID` - OIDC client ID for SSO
- `ROMM_OIDC_CLIENT_SECRET` - OIDC client secret
- `ROMM_AUTH_SECRET_KEY` - Session encryption key
- `RETROACHIEVEMENTS_API_KEY` - RetroAchievements API key (optional)
- `SCREENSCRAPER_USER` - ScreenScraper username (optional)
- `SCREENSCRAPER_PASSWORD` - ScreenScraper password (optional)

**Reference:** `kubernetes/base/downloads/romm/externalsecret.yaml`

### CLUSTER/steamgriddb (SteamGridDB - Game Artwork)

**Path:** `CLUSTER/steamgriddb` (e.g., `kdev/steamgriddb`, `korg/steamgriddb`)

SteamGridDB API for game artwork in ROMM.

**Required Keys:**

- `STEAMGRIDDB_API_KEY` - SteamGridDB API key

**Reference:** `kubernetes/base/downloads/romm/externalsecret.yaml`

### CLUSTER/seerr (Seerr - Media Request Manager)

**Path:** `CLUSTER/seerr` (e.g., `kdev/seerr`, `korg/seerr`)

Seerr API key for media request management.

**Required Keys:**

- `SEERR_API_KEY` - Seerr API key

**Reference:** `kubernetes/base/media/seerr/externalsecret.yaml`

## OIDC Client Secrets (Dynamic per App)

For apps that use OIDC/OAuth2 SSO, the following secrets are typically stored with keys:

- `client-id` - OIDC client ID
- `client-secret` - OIDC client secret

**Apps with OIDC:**

- Open WebUI (in `CLUSTER/open-webui`)
- PGAdmin (in `CLUSTER/pgadmin`)
- ROMM (in `CLUSTER/romm`)
- Grafana (in `CLUSTER/grafana`)
- Weave GitOps (in `CLUSTER/weave-gitops`)

These clients should be registered in your OIDC provider (e.g., Authelia, Keycloak) with:

- Redirect URIs: `https://APP.${SECRET_DOMAIN}/oauth2/callback`
- Scopes: `openid`, `profile`, `email`, `groups`

## Creation Workflow

### For Initial Bootstrap

1. **Create global secrets (once per Akeyless account):**

    ```
    ak://akeyless/ACCESS_ID
    ak://akeyless/ACCESS_TYPE_PARAM
    ak://github/GITHUB_WEBHOOK_TOKEN
    ak://github/GITHUB_NOTIFICATION_TOKEN
    ak://huggingface/HF_TOKEN
    ak://qnap/QNAP_URL
    ak://qnap/QNAP_HOSTNAME
    ak://qnap/S3_KEY_ID
    ak://qnap/S3_SECRET_KEY
    ```

2. **For each cluster (kdev, korg):**

    ```
    ak://CLUSTER-cluster/SECRET_DOMAIN
    ak://CLUSTER-cluster/INTERNAL_DOMAIN
    ak://CLUSTER-cluster/LDAP_BASE_DN
    ak://CLUSTER-cluster/QNAP_HOSTNAME
    ak://CLUSTER-cluster/CLOUDFLARE_TUNNEL_ID
    ```

3. **Create cluster-specific app secrets** (varies by deployment)

### Using akeyless CLI

```bash
# Create a secret
akeyless create-secret \
  --name "kdev-cluster/SECRET_DOMAIN" \
  --secret-value "kraven.org" \
  --secret-type "generic"

# Create a JSON secret (for multiple keys)
akeyless create-secret \
  --name "kdev/cloudflare" \
  --secret-value '{"CF_API_TOKEN":"token123","CF_ZONE_ID":"zone456","CF_TUNNEL_TOKEN":"tunnel789"}' \
  --secret-type "generic"

# Update an existing secret
akeyless update-secret \
  --name "kdev/cloudflare" \
  --secret-value '{"CF_API_TOKEN":"new_token",...}'
```

## Validation

After creating secrets, verify they're accessible:

```bash
# List all secrets for a cluster
akeyless list-secrets --path-prefix="kdev"

# Get a specific secret
akeyless get-secret-value --name "kdev-cluster/SECRET_DOMAIN"

# Test a token replacement (during bootstrap)
echo "domain: ak://kdev-cluster/SECRET_DOMAIN" | ./scripts/akeyless.sh
```

## Troubleshooting

**Placeholder values not substituted (`...PLACEHOLDER_...`):**

- Ensure secret exists in Akeyless
- Check Akeyless CLI is authenticated: `akeyless auth current`
- Verify path matches exactly (case-sensitive)
- Check cluster-settings ConfigMap has VAULT_PREFIX value

**ExternalSecret stuck in Pending:**

- `kubectl describe externalsecret -n NAMESPACE`
- `kubectl -n external-secrets logs -f deployment/external-secrets`
- Verify Akeyless credentials in `external-secrets` namespace: `kubectl get secret akeyless -n external-secrets`

**Secret not found during bootstrap:**

- Run akeyless.sh manually with token to verify access
- Ensure VAULT_PREFIX environment variable is set correctly
- Check bootstrap sequence (akeyless secret must exist before `bootstrap apps`)

## Additional Notes

- All JSON secrets are stored as single JSON objects (one per app)
- Base64-encoded TLS certificates must be wrapped in the `decodingStrategy: Base64` field
- Shared secrets (qnap, github, huggingface) are only created once but used by multiple clusters
- OIDC clients should be pre-configured in your identity provider before deploying apps
- Some apps generate database secrets separately (PostgreSQL, PGAdmin) via PGO operator
