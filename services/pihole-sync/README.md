# Pi-hole Sync Module

This module synchronizes Pi-hole configuration state from a source host to a
target host by using Pi-hole's built-in `pihole-FTL --teleporter` export/import
CLI.

It is designed for scheduled pull-based sync on a backup resolver, for example:

- `rpi-box-01` as the primary Pi-hole
- `rpi-box-02` as the secondary Pi-hole

## Why this approach

- It uses Pi-hole's own Teleporter mechanism instead of direct database or file
  replication.
- It matches the Pi-hole v6 CLI available in the currently deployed
  `pihole/pihole:2025.11.1` container.
- It avoids coupling the sync logic to internal SQLite file layouts.

## What it is for

Use this module to synchronize configuration state that should be consistent
between Pi-hole nodes:

- settings exported by Teleporter
- allow/deny lists and related Pi-hole state
- local DNS records and other Teleporter-managed configuration

This is the right fit for twice-daily consistency on a backup DNS node.

## What it is not for

This module is not intended to replicate live query traffic or provide
real-time state mirroring.

If you need immediate failover semantics or shared live counters, that is a
different design problem.

## How it works

On each timer run, the target host:

1. Optionally exports its own current state to a local backup archive.
2. Uses SSH to connect to the source host.
3. Runs `pihole-FTL --teleporter` inside the source Pi-hole container.
4. Streams the generated archive back to the target host.
5. Imports the archive into the local Pi-hole container with
   `pihole-FTL --teleporter <file>`.

## SSH requirements

This module expects:

- a dedicated SSH private key on the target host
- the matching public key authorized on the source host
- non-interactive `sudo -n docker exec ...` to be permitted for the SSH user on
  the source host

Store the private key as a runtime secret (for example via `sops-nix`) and pass
its path with `services.piholeSync.ssh.identityFile`.

The module stores SSH host keys in a local known-hosts file under
`/var/lib/pihole-sync/known_hosts` by default and uses
`StrictHostKeyChecking=accept-new` so the first scheduled run can persist the
source host key without an interactive prompt.

## Example

```nix
{
  imports = [
    inputs.nix-services.services.piholeSync
  ];

  sops.secrets.pihole-sync-ssh-key = {
    sopsFile = ../../../secrets/secrets.yaml;
    format = "yaml";
    key = "pihole-sync-ssh-key";
    path = "/run/secrets/pihole-sync-ssh-key";
    owner = "root";
    group = "root";
    mode = "0400";
  };

  services.piholeSync = {
    enable = true;

    source = {
      host = "rpi-box-01";
      user = "eduardo";
    };

    ssh.identityFile = config.sops.secrets.pihole-sync-ssh-key.path;

    schedule = "*-*-* 00,12:00:00";
    randomizedDelaySec = "15m";
  };
}
```

## Operational note

Because this is a scheduled import, the target Pi-hole should be treated as a
backup resolver. Clients can safely use it as a secondary DNS server, but it
will lag behind the primary by up to the timer interval.
