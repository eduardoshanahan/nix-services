{
  lib,
  pkgs,
}: {
  mkRuntimeSecretEnvExecStartPre = {
    name,
    secretFile,
    envVar,
  }:
    pkgs.writeShellScript "${name}-runtime-secret-env" ''
      set -euo pipefail
      umask 0077

      name=${lib.escapeShellArg name}
      secret_file=${lib.escapeShellArg (
        if secretFile == null
        then ""
        else toString secretFile
      )}
      env_var=${lib.escapeShellArg envVar}

      if [[ -z "$secret_file" ]]; then
        echo "$name: secretFile is null/empty" >&2
        exit 1
      fi

      if [[ "$secret_file" != /* ]]; then
        # name is used as a filename component and must be path-safe.
        echo "$name: secretFile must be an absolute path: $secret_file" >&2
        exit 1
      fi

      if [[ "$name" == *"/"* ]]; then
        echo "$name: name must not contain '/': $name" >&2
        exit 1
      fi

      if [[ ! -e "$secret_file" ]]; then
        echo "$name: secretFile does not exist: $secret_file" >&2
        exit 1
      fi

      if [[ ! -s "$secret_file" ]]; then
        echo "$name: secretFile is empty: $secret_file" >&2
        exit 1
      fi

      secret="$(cat "$secret_file")"
      secret="''${secret%$'\n'}"
      secret="''${secret%$'\r'}"

      if [[ -z "$secret" ]]; then
        echo "$name: secretFile is empty after trimming newline: $secret_file" >&2
        exit 1
      fi

      if [[ "$secret" == *$'\n'* || "$secret" == *$'\r'* ]]; then
        echo "$name: secretFile must be a single line (after trimming): $secret_file" >&2
        exit 1
      fi

      escaped="$secret"
      escaped="''${escaped//\\/\\\\}"
      escaped="''${escaped//\"/\\\"}"

      install -d -m 0700 /run/secrets
      chmod 0700 /run/secrets

      env_file="/run/secrets/$name.env"
      tmp="$(mktemp -p /run/secrets ".''${name}.env.XXXXXX")"

      printf '%s="%s"\n' "$env_var" "$escaped" > "$tmp"
      chmod 0600 "$tmp"
      mv -f "$tmp" "$env_file"
    '';
}
