# Service Image Versions

Reference table of all services across nix-services and synology-services, their container images, pinned versions, and paths.
Update this file whenever a service version is bumped.

Last updated: 2026-05-16

## nix-services (nixos)

NixOS services managed via Docker Compose rendered from Nix modules in `nix-services/services/`.

| Service | Image | Version/Tag | Full Path |
| --- | --- | --- | --- |
| alertmanager | `prom/alertmanager` | `v0.32.1` | `/home/eduardo/Programming/nix-services/nix-services/services/alertmanager/` |
| anki-sync | `anki-sync-local` (local build) | `25.09.2` | `/home/eduardo/Programming/nix-services/nix-services/services/anki-sync/` |
| authentik | `ghcr.io/goauthentik/server` | `2026.2.2` | `/home/eduardo/Programming/nix-services/nix-services/services/authentik/` |
| cadvisor | `gcr.io/cadvisor/cadvisor` | `v0.55.1` | `/home/eduardo/Programming/nix-services/nix-services/services/cadvisor/` |
| calibre-web-automated | `crocodilestick/calibre-web-automated` | `latest` | `/home/eduardo/Programming/nix-services/nix-services/services/calibre-web-automated/` |
| d2 | `terrastruct/d2` | `v0.7.1` | `/home/eduardo/Programming/nix-services/nix-services/services/d2/` |
| daysuntil | `gitea.hhlab.home.arpa/eduardo/daysuntil` | `latest` | `/home/eduardo/Programming/nix-services/nix-services/services/daysuntil/` |
| diagrams-net | `jgraph/drawio` | `29.7.12` | `/home/eduardo/Programming/nix-services/nix-services/services/diagrams-net/` |
| docker-socket-proxy | `docker.io/tecnativa/docker-socket-proxy` | `latest` | `/home/eduardo/Programming/nix-services/nix-services/services/docker-socket-proxy/` |
| dozzle | `amir20/dozzle` | `latest` | `/home/eduardo/Programming/nix-services/nix-services/services/dozzle/` |
| excalidraw | `excalidraw/excalidraw` | `latest` | `/home/eduardo/Programming/nix-services/nix-services/services/excalidraw/` |
| focalboard | (archived — README only, no module) | — | `/home/eduardo/Programming/nix-services/nix-services/services/focalboard/` |
| fossflow | `stnsmith/fossflow` | `sha256:a344fb844e931d65a74f8d00ded7c869f3070e346b288d4b8fe0437188468027` | `/home/eduardo/Programming/nix-services/nix-services/services/fossflow/` |
| ghost | `ghost` | `6.37.0` | `/home/eduardo/Programming/nix-services/nix-services/services/ghost/` |
| grafana | `grafana/grafana` | `13.0.1` | `/home/eduardo/Programming/nix-services/nix-services/services/grafana/` |
| homarr | `ghcr.io/homarr-labs/homarr` | `v1.60.0` | `/home/eduardo/Programming/nix-services/nix-services/services/homarr/` |
| home-assistant | `ghcr.io/home-assistant/home-assistant` | `2026.5.0` | `/home/eduardo/Programming/nix-services/nix-services/services/home-assistant/` |
| homepage | `ghcr.io/gethomepage/homepage` | `v1.12.3` | `/home/eduardo/Programming/nix-services/nix-services/services/homepage/` |
| karakeep | `ghcr.io/karakeep-app/karakeep` | `release` | `/home/eduardo/Programming/nix-services/nix-services/services/karakeep/` |
| karakeep (meilisearch) | `getmeili/meilisearch` | `v1.13.3` | `/home/eduardo/Programming/nix-services/nix-services/services/karakeep/` |
| lazylibrarian | `lscr.io/linuxserver/lazylibrarian` | `latest` | `/home/eduardo/Programming/nix-services/nix-services/services/lazylibrarian/` |
| lidarr | `lscr.io/linuxserver/lidarr` | `latest` | `/home/eduardo/Programming/nix-services/nix-services/services/lidarr/` |
| loki | `grafana/loki` | `3.7.1` | `/home/eduardo/Programming/nix-services/nix-services/services/loki/` |
| mongodb-exporter | `percona/mongodb_exporter` | `0.51.0` | `/home/eduardo/Programming/nix-services/nix-services/services/mongodb-exporter/` |
| mysql | `mysql` | `8.0.46` | `/home/eduardo/Programming/nix-services/nix-services/services/mysql/` |
| mysql-exporter | `prom/mysqld-exporter` | `v0.19.0` | `/home/eduardo/Programming/nix-services/nix-services/services/mysql-exporter/` |
| n8n | `docker.n8n.io/n8nio/n8n` | `2.20.6` | `/home/eduardo/Programming/nix-services/nix-services/services/n8n/` |
| owntracks-recorder | `owntracks/recorder` | `1.0.1-43` | `/home/eduardo/Programming/nix-services/nix-services/services/owntracks-recorder/` |
| pihole | `pihole/pihole` | `2026.04.1` | `/home/eduardo/Programming/nix-services/nix-services/services/pihole/` |
| pihole-exporter | `ekofr/pihole-exporter` | `v1.2.0` | `/home/eduardo/Programming/nix-services/nix-services/services/pihole-exporter/` |
| pihole-sync | (no container — SSH/systemd timer) | — | `/home/eduardo/Programming/nix-services/nix-services/services/pihole-sync/` |
| postgres-exporter | `quay.io/prometheuscommunity/postgres-exporter` | `v0.19.1` | `/home/eduardo/Programming/nix-services/nix-services/services/postgres-exporter/` |
| prometheus | `prom/prometheus` | `v3.11.3` | `/home/eduardo/Programming/nix-services/nix-services/services/prometheus/` |
| promtail | `grafana/promtail` | `3.6.10` | `/home/eduardo/Programming/nix-services/nix-services/services/promtail/` |
| prowlarr | `lscr.io/linuxserver/prowlarr` | `latest` | `/home/eduardo/Programming/nix-services/nix-services/services/prowlarr/` |
| radarr | `lscr.io/linuxserver/radarr` | `latest` | `/home/eduardo/Programming/nix-services/nix-services/services/radarr/` |
| redis-exporter | `oliver006/redis_exporter` | `v1.83.0` | `/home/eduardo/Programming/nix-services/nix-services/services/redis-exporter/` |
| searxng | `searxng/searxng` | `sha256:754a07a64e926a1fc0a8a30cd7a07d08278188f0ef6143e38ad0b22ea8599c55` | `/home/eduardo/Programming/nix-services/nix-services/services/searxng/` |
| seerr | `ghcr.io/seerr-team/seerr` | `v3.2.0` | `/home/eduardo/Programming/nix-services/nix-services/services/seerr/` |
| smtp-relay | `boky/postfix` | `5.1.0` | `/home/eduardo/Programming/nix-services/nix-services/services/smtp-relay/` |
| snmp-exporter | `prom/snmp-exporter` | `v0.30.1` | `/home/eduardo/Programming/nix-services/nix-services/services/snmp-exporter/` |
| sonarr | `lscr.io/linuxserver/sonarr` | `latest` | `/home/eduardo/Programming/nix-services/nix-services/services/sonarr/` |
| tailscale | `tailscale/tailscale` | `v1.96.5` | `/home/eduardo/Programming/nix-services/nix-services/services/tailscale/` |
| timetagger | `ghcr.io/almarklein/timetagger` | `latest` | `/home/eduardo/Programming/nix-services/nix-services/services/timetagger/` |
| traefik | `traefik` | `v3.7.0` | `/home/eduardo/Programming/nix-services/nix-services/services/traefik/` |
| traggo | `traggo/server` | `latest` | `/home/eduardo/Programming/nix-services/nix-services/services/traggo/` |
| umami | `ghcr.io/umami-software/umami` | `postgresql-latest` | `/home/eduardo/Programming/nix-services/nix-services/services/umami/` |
| unpoller | `ghcr.io/unpoller/unpoller` | `v2.39.0` | `/home/eduardo/Programming/nix-services/nix-services/services/unpoller/` |
| uptime-kuma | `louislam/uptime-kuma` | `2.3.2` | `/home/eduardo/Programming/nix-services/nix-services/services/uptime-kuma/` |
| vikunja | `vikunja/vikunja` | `2.3.0` | `/home/eduardo/Programming/nix-services/nix-services/services/vikunja/` |
| woodpecker | `woodpeckerci/woodpecker-server` | `latest` | `/home/eduardo/Programming/nix-services/nix-services/services/woodpecker/` |

## synology-services (hhnas4)

Host: `hhnas4`. Services managed via Docker Compose in `synology-services/hhnas4/`.

| Service | Image | Version/Tag | Full Path |
| --- | --- | --- | --- |
| adminer | `adminer` | `5.4.2` | `/home/eduardo/Programming/synology-services/synology-services/hhnas4/adminer/` |
| archivebox | `archivebox/archivebox` | `sha256:fdf2936192aa1e909b0c3f286f60174efa24078555be4b6b90a07f2cef1d4909` | `/home/eduardo/Programming/synology-services/synology-services/hhnas4/archivebox/` |
| docker-socket-proxy | `docker.io/tecnativa/docker-socket-proxy` | `sha256:1f3a6f303320723d199d2316a3e82b2e2685d86c275d5e3deeaf182573b47476` | `/home/eduardo/Programming/synology-services/synology-services/hhnas4/docker-socket-proxy/` |
| dolt | `dolthub/dolt-sql-server` | `1.86.0` | `/home/eduardo/Programming/synology-services/synology-services/hhnas4/dolt/` |
| freshrss | `freshrss/freshrss` | `1.28.1` | `/home/eduardo/Programming/synology-services/synology-services/hhnas4/freshrss/` |
| gitea | `docker.gitea.com/gitea` | `1.25.5` | `/home/eduardo/Programming/synology-services/synology-services/hhnas4/gitea/` |
| gotenberg | `gotenberg/gotenberg` | `8.30` | `/home/eduardo/Programming/synology-services/synology-services/hhnas4/gotenberg/` |
| immich (server) | `ghcr.io/immich-app/immich-server` | env-defined (`IMMICH_VERSION`, encrypted) | `/home/eduardo/Programming/synology-services/synology-services/hhnas4/immich/` |
| immich (ml) | `ghcr.io/immich-app/immich-machine-learning` | env-defined (`IMMICH_VERSION`, encrypted) | `/home/eduardo/Programming/synology-services/synology-services/hhnas4/immich/` |
| jellyfin | `jellyfin/jellyfin` | `10.11.8` | `/home/eduardo/Programming/synology-services/synology-services/hhnas4/jellyfin/` |
| karakeep | `ghcr.io/karakeep-app/karakeep` | `sha256:20754dbdafb11dfe288bbb1c2342a7855081b08ea069e86fcf2d4a2d945d3653` | `/home/eduardo/Programming/synology-services/synology-services/hhnas4/karakeep/` |
| karakeep (chrome) | `gcr.io/zenika-hub/alpine-chrome` | `124` | `/home/eduardo/Programming/synology-services/synology-services/hhnas4/karakeep/` |
| karakeep (meilisearch) | `getmeili/meilisearch` | `v1.13.3` | `/home/eduardo/Programming/synology-services/synology-services/hhnas4/karakeep/` |
| minio | `minio/minio` | `RELEASE.2025-09-07T16-13-09Z` | `/home/eduardo/Programming/synology-services/synology-services/hhnas4/minio/` |
| mongo | `mongo` | `4.4.30` | `/home/eduardo/Programming/synology-services/synology-services/hhnas4/mongo/` |
| mysql | `mysql` | `8.4.8` | `/home/eduardo/Programming/synology-services/synology-services/hhnas4/mysql/` |
| outline | `docker.getoutline.com/outlinewiki/outline` | `1.6.1` | `/home/eduardo/Programming/synology-services/synology-services/hhnas4/outline/` |
| paperless | `ghcr.io/paperless-ngx/paperless-ngx` | `2.20.13` | `/home/eduardo/Programming/synology-services/synology-services/hhnas4/paperless/` |
| postgres | `pgvector/pgvector` | `0.8.1-pg17-bookworm` | `/home/eduardo/Programming/synology-services/synology-services/hhnas4/postgres/` |
| promtail | `grafana/promtail` | `3.6.10` | `/home/eduardo/Programming/synology-services/synology-services/hhnas4/promtail/` |
| qbittorrent | `lscr.io/linuxserver/qbittorrent` | `5.1.4-r2-ls445` | `/home/eduardo/Programming/synology-services/synology-services/hhnas4/qbittorrent/` |
| redis | `redis` | `7.4.8-alpine` | `/home/eduardo/Programming/synology-services/synology-services/hhnas4/redis/` |
| scholarsome | `hwgilbert16/scholarsome` | `v1.2.1` | `/home/eduardo/Programming/synology-services/synology-services/hhnas4/scholarsome/` |
| tika | `apache/tika` | `3.3.0.0` | `/home/eduardo/Programming/synology-services/synology-services/hhnas4/tika/` |
| wireguard | `masipcat/wireguard-go` | `sha256:696206e5954d3bdeaa59d5a006dc8de7d9ccdbe1fb0ac1b41650ea75cbd133e9` | `/home/eduardo/Programming/synology-services/synology-services/hhnas4/wireguard/` |
| woodpecker-agent | `woodpeckerci/woodpecker-agent` | `v2.8.3` | `/home/eduardo/Programming/synology-services/synology-services/hhnas4/woodpecker-agent/` |

## nix-cluster (kubernetes)

Cluster services managed via Helm + Kustomize. Helm chart versions are pinned in `kustomization.yaml`; direct image deployments are in `deployment.yaml`.

| Service | Image / Helm Chart | Version | Full Path |
| --- | --- | --- | --- |
| cilium | Helm: `cilium` | chart `1.16.19` | `/home/eduardo/Programming/nix-cluster/nix-cluster/kubernetes/platform/networking/cilium/` |
| headlamp | Helm: `headlamp` | chart `0.41.0` | `/home/eduardo/Programming/nix-cluster/nix-cluster/kubernetes/operations/headlamp/` |
| kafka-ui | Helm: `kafka-ui` | chart `1.6.3` | `/home/eduardo/Programming/nix-cluster/nix-cluster/kubernetes/apps/kafka/kafka-ui/` |
| kube-state-metrics | Helm: `kube-state-metrics` | chart `7.2.2` | `/home/eduardo/Programming/nix-cluster/nix-cluster/kubernetes/platform/observability/kube-state-metrics/` |
| metallb | Helm: `metallb` | chart `0.15.3` | `/home/eduardo/Programming/nix-cluster/nix-cluster/kubernetes/platform/networking/metallb/` |
| schema-registry | `confluentinc/cp-schema-registry` | `7.9.2` | `/home/eduardo/Programming/nix-cluster/nix-cluster/kubernetes/apps/kafka/schema-registry/` |
| spark (history server) | `apache/spark` | `3.5.3` | `/home/eduardo/Programming/nix-cluster/nix-cluster/kubernetes/apps/spark/spark-history-server/` |
| spark (jupyter) | `spark-jupyter` (local build) | `3.5.3` | `/home/eduardo/Programming/nix-cluster/nix-cluster/kubernetes/apps/spark/jupyter/` |
| spark-operator | Helm: `spark-kubernetes-operator` | chart `1.6.0` / app `0.8.0` | `/home/eduardo/Programming/nix-cluster/nix-cluster/kubernetes/apps/spark/spark-operator/` |
| strimzi-operator | Helm: `strimzi-kafka-operator` | chart `0.51.0` | `/home/eduardo/Programming/nix-cluster/nix-cluster/kubernetes/apps/kafka/strimzi-operator/` |
| traefik | Helm: `traefik` | chart `39.0.7` | `/home/eduardo/Programming/nix-cluster/nix-cluster/kubernetes/platform/networking/traefik/` |
| wikijs | `ghcr.io/requarks/wiki` | `2.5.300` | `/home/eduardo/Programming/nix-cluster/nix-cluster/kubernetes/apps/wikijs/wikijs/` |
| \*-metrics-proxy (×3) | `python` | `3.13-alpine` | `/home/eduardo/Programming/nix-cluster/nix-cluster/kubernetes/platform/observability/{apiserver,control-plane,kubelet}-metrics-proxy/` |

## Notes

### nix-services

- **`latest` tag** — several services (calibre-web-automated, daysuntil, docker-socket-proxy, dozzle, excalidraw, lazylibrarian, lidarr, prowlarr, radarr, sonarr, timetagger, traggo, woodpecker) use `latest` or an unpinned alias. These violate the pinning policy and are candidates for version pinning.
- **digest-pinned** — fossflow and searxng are pinned via sha256 digest instead of a named tag, which is an acceptable alternative to version tags.
- **linuxserver.io tag format** — when pinning linuxserver images, use `{version}-ls{N}` (e.g. `2.3.5.5327-ls142`), not the bare app version. See known-mistakes.
- **karakeep** uses `release` (effectively unpinned); also bundles meilisearch `v1.13.3` as a companion container.
- **focalboard** — directory contains only a README; likely archived.
- **pihole-sync** — not a container; implemented as a systemd timer + SSH rsync.
- **anki-sync** — locally built image; version tracks the upstream Anki sync server release.

### synology-services

- **immich** — version is set via `IMMICH_VERSION` in a sops-encrypted `.env`; not readable from the repo directly.
- **paperless / qbittorrent** — version is the compose default; actual value may be overridden by env file.
- **digest-pinned** — archivebox, docker-socket-proxy, karakeep, and wireguard are pinned via sha256 digest.

### nix-cluster

- **Helm chart versions** are the pinned chart version in `kustomization.yaml`; the upstream app version embedded in the chart may differ.
- **spark-jupyter** is a locally built image (`spark-jupyter:3.5.3`) matching the Spark runtime version.
- **metrics-proxy** deployments (apiserver, control-plane, kubelet) are thin Python scripts using a shared `python:3.13-alpine` image.
