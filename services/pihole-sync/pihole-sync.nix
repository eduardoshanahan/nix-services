{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.piholeSync;
  runtimeSecrets = import ../../lib/runtime-secrets.nix {inherit lib;};
  dockerBin = "${config.virtualisation.docker.package}/bin/docker";

  remoteExportCommand =
    "sudo -n /run/current-system/sw/bin/docker exec ${cfg.sourceContainerName} sh -lc "
    + lib.escapeShellArg ''
      cd /tmp
      archive="$(pihole-FTL --teleporter | tail -n 1)"
      cat "/tmp/$archive"
      rm -f "/tmp/$archive"
    '';

  localExportCommand =
    "${dockerBin} exec ${cfg.targetContainerName} sh -lc "
    + lib.escapeShellArg ''
      cd /tmp
      archive="$(pihole-FTL --teleporter | tail -n 1)"
      cat "/tmp/$archive"
      rm -f "/tmp/$archive"
    '';

  syncScript = pkgs.writeShellScript "pihole-sync" ''
    set -euo pipefail

    PATH=${lib.makeBinPath [pkgs.coreutils pkgs.findutils pkgs.openssh]}

    workdir="$(mktemp -d /run/pihole-sync.XXXXXX)"
    incoming_archive="$workdir/source.teleporter.zip"

    cleanup() {
      rm -rf "$workdir"
    }

    trap cleanup EXIT

    install -d -m 0700 ${lib.escapeShellArg cfg.stateDir}
    touch ${lib.escapeShellArg cfg.ssh.knownHostsFile}
    chmod 0600 ${lib.escapeShellArg cfg.ssh.knownHostsFile}

    ${
      lib.optionalString cfg.backup.enable ''
        backup_stamp="$(date -u +%Y%m%dT%H%M%SZ)"
        backup_archive="${cfg.backup.directory}/pihole-target-$backup_stamp.zip"

        ${localExportCommand} > "$backup_archive"
        chmod 0600 "$backup_archive"

        find ${lib.escapeShellArg cfg.backup.directory} \
          -maxdepth 1 \
          -type f \
          -name 'pihole-target-*.zip' \
          -mtime +${toString cfg.backup.keepDays} \
          -delete
      ''
    }

    ${pkgs.openssh}/bin/ssh -i ${lib.escapeShellArg cfg.ssh.identityFile} -o BatchMode=yes -o IdentitiesOnly=yes -o StrictHostKeyChecking=${cfg.ssh.strictHostKeyChecking} -o UserKnownHostsFile=${lib.escapeShellArg cfg.ssh.knownHostsFile} ${lib.escapeShellArg "${cfg.source.user}@${cfg.source.host}"} ${lib.escapeShellArg remoteExportCommand} > "$incoming_archive"

    if [ ! -s "$incoming_archive" ]; then
      echo "pihole-sync: received empty Teleporter archive from source" >&2
      exit 1
    fi

    ${dockerBin} cp "$incoming_archive" ${lib.escapeShellArg cfg.targetContainerName}:/tmp/pihole-sync.teleporter.zip
    ${dockerBin} exec ${lib.escapeShellArg cfg.targetContainerName} pihole-FTL --teleporter /tmp/pihole-sync.teleporter.zip
    ${dockerBin} exec ${lib.escapeShellArg cfg.targetContainerName} rm -f /tmp/pihole-sync.teleporter.zip
  '';
in {
  options.services.piholeSync = {
    enable = lib.mkEnableOption "scheduled Pi-hole state sync via the built-in Teleporter CLI";

    source = {
      host = lib.mkOption {
        type = lib.types.str;
        description = "Source host to pull the Teleporter archive from (for example `dns-primary.internal.example`).";
      };

      user = lib.mkOption {
        type = lib.types.str;
        description = "SSH user used to connect to the source host.";
      };
    };

    sourceContainerName = lib.mkOption {
      type = lib.types.str;
      default = "pihole";
      description = "Pi-hole container name on the source host.";
    };

    targetContainerName = lib.mkOption {
      type = lib.types.str;
      default = "pihole";
      description = "Local Pi-hole container name that receives the imported Teleporter archive.";
    };

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "*-*-* 00,12:00:00";
      description = "Systemd OnCalendar expression for the sync timer.";
    };

    randomizedDelaySec = lib.mkOption {
      type = lib.types.str;
      default = "15m";
      description = "Randomized delay applied by the timer before each run.";
    };

    ssh = {
      identityFile = runtimeSecrets.mkSecretFileOption {
        description = ''
          Absolute path to the SSH private key used to reach the source host.
          The matching public key should be authorized on the source host for the
          configured source user.
        '';
        example = "/run/secrets/pihole-sync-ssh-key";
      };

      knownHostsFile = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/pihole-sync/known_hosts";
        description = ''
          Absolute path to a dedicated known_hosts file for the source host.
        '';
      };

      strictHostKeyChecking = lib.mkOption {
        type = lib.types.enum [ "accept-new" "yes" "no" ];
        default = "accept-new";
        description = ''
          SSH StrictHostKeyChecking mode used by the scheduled sync.
          `accept-new` is the default so the first successful connection can
          persist the source host key without interactive prompts.
        '';
      };
    };

    backup = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Export the local target state before each import.";
      };

      directory = lib.mkOption {
        type = lib.types.str;
        default = "/var/backups/pihole-sync";
        description = "Directory where pre-import local Teleporter backups are stored.";
      };

      keepDays = lib.mkOption {
        type = lib.types.ints.positive;
        default = 14;
        description = "How many days of local pre-import backups to keep.";
      };
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/pihole-sync";
      description = "Local state directory used by the sync job (for example for known_hosts).";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.pihole.enable;
        message = "services.piholeSync requires services.pihole.enable = true on the target host.";
      }
      {
        assertion = cfg.ssh.identityFile != null;
        message = "services.piholeSync.ssh.identityFile must be set when enabling Pi-hole sync.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.backup.directory;
        message = "services.piholeSync.backup.directory must be an absolute path.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.stateDir;
        message = "services.piholeSync.stateDir must be an absolute path.";
      }
      {
        assertion = lib.hasPrefix "/" cfg.ssh.knownHostsFile;
        message = "services.piholeSync.ssh.knownHostsFile must be an absolute path.";
      }
    ];

    virtualisation.docker.enable = true;

    systemd.tmpfiles.rules = lib.optionals cfg.backup.enable [
      "d ${cfg.backup.directory} 0700 root root - -"
    ] ++ [
      "d ${cfg.stateDir} 0700 root root - -"
    ];

    systemd.services.pihole-sync = {
      description = "Pi-hole state sync from ${cfg.source.user}@${cfg.source.host}";
      after = [
        "docker.service"
        "network-online.target"
        "pihole.service"
      ];
      wants = [ "network-online.target" ];
      requires = [
        "docker.service"
        "pihole.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = syncScript;
      };
    };

    systemd.timers.pihole-sync = {
      description = "Run Pi-hole state sync on schedule";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.schedule;
        RandomizedDelaySec = cfg.randomizedDelaySec;
        Persistent = true;
        Unit = "pihole-sync.service";
      };
    };
  };
}
