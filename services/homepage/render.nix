{
  lib,
  cfg,
  imageRef,
  configDir,
  allowedHosts,
}: let
  entrypoints =
    if cfg.tls
    then "websecure"
    else "web";
  tlsEnabled =
    if cfg.tls
    then "true"
    else "false";
  allowedHostsValue = lib.concatStringsSep "," allowedHosts;
  defaultSettings =
    {
      title = "Homelab";
      description = "Service dashboard";
    }
    // lib.optionalAttrs cfg.docker.enable {
      showStats = true;
      instanceName = cfg.docker.instanceName;
    };
  settingsYaml = defaultSettings // cfg.config.settings;
  servicesYaml = cfg.config.services;
  bookmarksYaml = cfg.config.bookmarks;
  widgetsYaml = cfg.config.widgets;
  dockerYaml =
    (
      if cfg.docker.enable
      then {
        "${cfg.docker.instanceName}" = {
          socket = cfg.docker.socketPath;
        };
      }
      else {}
    )
    // cfg.config.docker;
  volumeLines =
    [
      "          - ${configDir}:/app/config:ro"
    ]
    ++ lib.optional cfg.docker.enable "          - ${cfg.docker.socketPath}:/var/run/docker.sock:ro";
  composeYaml = ''
    services:
      homepage:
        image: ${imageRef}
        container_name: ${cfg.containerName}
        restart: unless-stopped
        init: true
        mem_limit: 512m
        pids_limit: 256
        cpus: "1.0"

        expose:
          - "3000"

        volumes:
${lib.concatStringsSep "\n" volumeLines}
        environment:
          - HOMEPAGE_ALLOWED_HOSTS=${allowedHostsValue}
          - TZ=${cfg.timezone}

        labels:
          - "traefik.enable=true"
          - "traefik.docker.network=${cfg.network}"
          - "traefik.http.routers.homepage.rule=Host(`${cfg.hostname}`)"
          - "traefik.http.services.homepage.loadbalancer.server.port=3000"
          - "traefik.http.routers.homepage.entrypoints=${entrypoints}"
          - "traefik.http.routers.homepage.tls=${tlsEnabled}"
          - "traefik.http.routers.homepage.middlewares=homepage-sec@docker"
          - "traefik.http.middlewares.homepage-sec.headers.stsSeconds=31536000"
          - "traefik.http.middlewares.homepage-sec.headers.frameDeny=true"
          - "traefik.http.middlewares.homepage-sec.headers.contentTypeNosniff=true"
          - "traefik.http.middlewares.homepage-sec.headers.referrerPolicy=no-referrer"

        networks:
          - traefik

    networks:
      traefik:
        external: true
        name: ${cfg.network}
  '';
in {
  inherit composeYaml settingsYaml servicesYaml bookmarksYaml widgetsYaml dockerYaml;
}
