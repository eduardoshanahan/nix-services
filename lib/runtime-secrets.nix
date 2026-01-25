{lib}: let
  absolutePathType =
    lib.types.addCheck (lib.types.oneOf [lib.types.str lib.types.path])
    (value: lib.hasPrefix "/" (toString value));
in {
  inherit absolutePathType;

  mkSecretFileOption = {
    description ? "Absolute path to a runtime-provisioned secret file (e.g. `/run/secrets/service.env`).",
    example ? "/run/secrets/service.env",
  }:
    lib.mkOption {
      type = lib.types.nullOr absolutePathType;
      default = null;
      inherit description example;
    };

  mkSecretFileEnvVar = {
    envVar,
    secretFile,
    fallback ? null,
  }:
    if secretFile != null
    then ["${envVar}=${toString secretFile}"]
    else if fallback != null
    then ["${envVar}=${fallback}"]
    else [];
}
