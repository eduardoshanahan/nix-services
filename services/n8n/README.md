# n8n service

n8n is packaged here as a Docker Compose-backed NixOS module.

- Compose file lives at `services/n8n/docker-compose.yml`.
- The module exports `services.n8nCompose`.
- Persistent state stays under `services.n8nCompose.dataDir` and should be
  pointed at a dedicated host path such as `/srv/n8n`.
- Runtime secrets are read from files and rendered into `/run/secrets/n8n.env`
  at service start.

Important options:

- `services.n8nCompose.enable`
- `services.n8nCompose.hostname`
- `services.n8nCompose.dataDir`
- `services.n8nCompose.database.postgres.host`
- `services.n8nCompose.database.postgres.port`
- `services.n8nCompose.database.postgres.name`
- `services.n8nCompose.database.postgres.user`
- `services.n8nCompose.database.postgres.passwordFile`
- `services.n8nCompose.encryptionKeyFile`
- `services.n8nCompose.image.repository`
- `services.n8nCompose.image.tag`
- `services.n8nCompose.tls`

Example:

```nix
services.n8nCompose = {
  enable = true;
  hostname = "n8n.${config.lab.domain}";
  tls = true;
  dataDir = "/srv/n8n";
  database.postgres = {
    host = "postgres.${config.lab.domain}";
    port = 5433;
    name = "n8n";
    user = "n8n";
    passwordFile = "/run/secrets/n8n-db-password";
  };
  encryptionKeyFile = "/run/secrets/n8n-encryption-key";
};
```
