# Umami Web Analytics Service

NixOS module for deploying Umami web analytics using Docker Compose.

## Overview

Umami is a simple, fast, privacy-focused alternative to Google Analytics. This module deploys Umami v3 with PostgreSQL or MySQL database support.

## Features

- PostgreSQL or MySQL backend support
- Custom tracker script naming (ad-blocker evasion)
- Configurable listen address and port
- Health check monitoring
- SOPS-compatible secret management

## Configuration Example

```nix
services.umamiCompose = {
  enable = true;
  listenAddress = "10.100.0.1";  # Bind to the host's WireGuard interface
  listenPort = 3000;

  database = {
    type = "postgresql";
    host = "192.0.2.10";  # PostgreSQL host IP
    port = 5433;
    name = "umami";
    user = "umami";
    passwordFile = "/run/secrets/umami_db_password";
  };

  appSecretFile = "/run/secrets/umami_app_secret";
  trackerScriptName = "getinfo";  # Custom script name

  image = {
    tag = "postgresql-latest";  # Use PostgreSQL-compatible image
  };
};
```

## Secrets

Two secrets are required:

1. **Database Password** (`database.passwordFile`): Database authentication
2. **App Secret** (`appSecretFile`): Random hash salt for Umami (32-byte hex recommended)

Generate secrets:

```bash
# App secret (32-byte hex)
openssl rand -hex 32

# Database password
openssl rand -base64 32
```

## Database Setup

### PostgreSQL

```sql
CREATE ROLE umami LOGIN PASSWORD 'your-password-here';
CREATE DATABASE umami OWNER umami;
GRANT ALL PRIVILEGES ON DATABASE umami TO umami;
```

### MySQL

```sql
CREATE DATABASE umami;
CREATE USER 'umami'@'%' IDENTIFIED BY 'your-password-here';
GRANT ALL PRIVILEGES ON umami.* TO 'umami'@'%';
FLUSH PRIVILEGES;
```

## Tracker Script Integration

Add to your website's HTML (in `<head>` or before `</body>`):

```html
<script defer data-website-id="YOUR_WEBSITE_ID" src="http://your-umami-host:3000/getinfo"></script>
```

Replace:

- `YOUR_WEBSITE_ID`: Website ID from Umami dashboard
- `your-umami-host:3000`: Your Umami server address
- `getinfo`: Your configured `trackerScriptName`

## Default Login

First-time login credentials:

- **Username**: `admin`
- **Password**: `umami`

**Important**: Change the admin password immediately after first login.

## Health Check

Umami provides a heartbeat endpoint for health monitoring:

```bash
curl http://your-umami-host:3000/api/heartbeat
# Expected: {"ok":true}
```

## Image Tags

- `postgresql-latest`: Latest Umami with PostgreSQL support (recommended)
- `mysql-latest`: Latest Umami with MySQL support
- Specific versions: e.g., `v2.19.0` (pinned releases)

## Resource Requirements

Typical resource usage:

- **RAM**: ~200MB
- **CPU**: Minimal (event-driven)
- **Disk**: Minimal (database stores analytics data)

## Network Ports

- **3000**: Umami web interface and API

## References

- [Umami Documentation](https://umami.is/docs)
- [Umami GitHub](https://github.com/umami-software/umami)
- [Docker Hub](https://hub.docker.com/r/ghcr.io/umami-software/umami)
