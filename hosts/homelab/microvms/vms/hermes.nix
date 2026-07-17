{
  lib,
  pkgs,
  ...
}:
let
  ids = {
    hermes = 998;
    hindsight = 1000;
  };
  paths = rec {
    root = "/var/lib/hermes";
    data = "${root}/data";
    plugins = "${data}/plugins";
    workspace = "${data}/workspace";
    hindsight = "${root}/hindsight";
    hindsightDatabase = "${hindsight}/pg0";
    docker = "${root}/docker";
  };
  images = {
    hermes = pkgs.generated.hermes_agent_image;
    hindsight = pkgs.generated.hindsight_image;
  };
  settings = import ./hermes/settings.nix;
  managedPlugins = import ./hermes/plugins.nix { inherit pkgs; };
  managedPluginNames = map (plugin: plugin.name) managedPlugins;
  managedPluginNamesFile = pkgs.writeText "hermes-managed-plugins" (
    lib.concatMapStringsSep "\n" (name: name) managedPluginNames + "\n"
  );
  hermesConfig = (pkgs.formats.yaml { }).generate "hermes-config.yaml" settings.hermes;
  hindsightConfig =
    (pkgs.formats.json { }).generate "hermes-hindsight-config.json"
      settings.hindsight;
  waitForHindsight = pkgs.writeShellScript "wait-for-hindsight" ''
    set -eu
    for attempt in $(${pkgs.coreutils}/bin/seq 1 180); do
      if ${pkgs.curl}/bin/curl --fail --silent --show-error \
        --max-time 2 http://127.0.0.1:8888/health >/dev/null; then
        exit 0
      fi
      ${pkgs.coreutils}/bin/sleep 1
    done
    echo "Hindsight did not become healthy within 180 seconds" >&2
    exit 1
  '';
  hindsightStart = pkgs.writeShellScript "hindsight-start" ''
    set -a
    . /run/secrets/hindsight.env
    set +a
    exec /app/start-all.sh
  '';
in
{
  imports = [
    (import ./caddy-proxy.nix {
      upstream = "http://127.0.0.1:9119";
      rewriteOrigin = true;
    })
  ];

  users.users.hermes = {
    uid = ids.hermes;
    group = "hermes";
    isSystemUser = true;
  };
  users.groups.hermes.gid = ids.hermes;
  users.groups.hindsight.gid = ids.hindsight;

  virtualisation.docker.daemon.settings.data-root = paths.docker;

  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      hindsight = {
        image = "ghcr.io/vectorize-io/hindsight:${images.hindsight.version}";
        imageFile = images.hindsight.src;
        pull = "never";
        autoStart = true;
        cmd = [
          "/bin/bash"
          "/run/hindsight-start"
        ];
        environment = {
          HINDSIGHT_API_LLM_PROVIDER = "deepseek";
          HINDSIGHT_API_LLM_MODEL = "deepseek-v4-flash";
          HINDSIGHT_API_LLM_BASE_URL = "https://api.deepseek.com";
          HINDSIGHT_API_EMBEDDINGS_PROVIDER = "local";
          HINDSIGHT_API_RERANKER_PROVIDER = "rrf";
          HINDSIGHT_API_WORKER_ID = "hermes-hindsight";
        };
        volumes = [
          "${paths.hindsightDatabase}:/home/hindsight/.pg0"
          "/var/keys/hindsight.env:/run/secrets/hindsight.env:ro"
          "${hindsightStart}:/run/hindsight-start:ro"
        ];
        ports = [
          "127.0.0.1:8888:8888"
          "127.0.0.1:9999:9999"
        ];
        extraOptions = [ "--stop-timeout=35" ];
      };

      hermes = {
        image = "nousresearch/hermes-agent:${images.hermes.version}";
        imageFile = images.hermes.src;
        pull = "never";
        autoStart = true;
        cmd = [
          "gateway"
          "run"
        ];
        environment = {
          HERMES_HOME = "/opt/data";
          HERMES_UID = toString ids.hermes;
          HERMES_GID = toString ids.hermes;
          HERMES_DASHBOARD = "1";
          HERMES_DASHBOARD_TUI = "1";
          HERMES_DASHBOARD_HOST = "127.0.0.1";
          HERMES_DASHBOARD_PORT = "9119";
          HERMES_DISABLE_LAZY_INSTALLS = "0";
        };
        volumes = [
          "${paths.data}:/opt/data"
          "/var/keys/hermes.env:/opt/data/.env:ro"
        ];
        extraOptions = [ "--network=host" ];
      };
    };
  };

  systemd.tmpfiles.rules = [
    "d ${paths.root} 0750 root root - -"
    "d ${paths.data} 2770 ${toString ids.hermes} ${toString ids.hermes} - -"
    "d ${paths.plugins} 2770 ${toString ids.hermes} ${toString ids.hermes} - -"
    "d ${paths.workspace} 2770 ${toString ids.hermes} ${toString ids.hermes} - -"
    "d ${paths.hindsight} 0750 ${toString ids.hindsight} ${toString ids.hindsight} - -"
    "d ${paths.hindsightDatabase} 0750 ${toString ids.hindsight} ${toString ids.hindsight} - -"
    "d ${paths.docker} 0710 root root - -"
  ];

  systemd.services = {
    hermes-bootstrap = {
      description = "Seed Hermes state and reconcile Nix-managed plugins";
      before = [ "docker-hermes.service" ];
      wantedBy = [ "docker-hermes.service" ];
      after = [
        "local-fs.target"
        "microvm-install-keys.service"
      ];
      requires = [ "microvm-install-keys.service" ];
      unitConfig.RequiresMountsFor = paths.root;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        UMask = "0007";
      };
      script = ''
        set -eu

        install -d -o ${toString ids.hermes} -g ${toString ids.hermes} -m 2770 \
          ${paths.data} ${paths.plugins} ${paths.workspace} ${paths.data}/hindsight

        if [ ! -e ${paths.data}/config.yaml ]; then
          install -o ${toString ids.hermes} -g ${toString ids.hermes} -m 0640 \
            ${hermesConfig} ${paths.data}/config.yaml
        fi
        if [ ! -e ${paths.data}/hindsight/config.json ]; then
          install -o ${toString ids.hermes} -g ${toString ids.hermes} -m 0640 \
            ${hindsightConfig} ${paths.data}/hindsight/config.json
        fi
        if [ ! -e ${paths.data}/SOUL.md ]; then
          install -o ${toString ids.hermes} -g ${toString ids.hermes} -m 0640 \
            /var/keys/hermes.SOUL.md ${paths.data}/SOUL.md
        fi
        if [ ! -e ${paths.data}/.env ]; then
          install -o ${toString ids.hermes} -g ${toString ids.hermes} -m 0600 \
            /dev/null ${paths.data}/.env
        fi

        while IFS= read -r plugin_dir; do
          plugin_name="$(${pkgs.coreutils}/bin/basename "$plugin_dir")"
          if ! ${pkgs.gnugrep}/bin/grep -Fqx "$plugin_name" ${managedPluginNamesFile}; then
            echo "Removing stale Nix-managed Hermes plugin: $plugin_name"
            ${pkgs.coreutils}/bin/rm -rf -- "$plugin_dir"
          fi
        done < <(${pkgs.findutils}/bin/find ${paths.plugins} -mindepth 1 -maxdepth 1 \
          -type d -exec ${pkgs.coreutils}/bin/test -f '{}/.nix-managed' ';' -print)

        ${lib.concatMapStringsSep "\n" (plugin: ''
          if [ ! -f ${plugin.src}/plugin.yaml ]; then
            echo "Nix-managed Hermes plugin '${plugin.name}' has no plugin.yaml" >&2
            exit 1
          fi
          plugin_tmp=${paths.plugins}/.${plugin.name}.nix-new
          plugin_target=${paths.plugins}/${plugin.name}
          ${pkgs.coreutils}/bin/rm -rf -- "$plugin_tmp"
          ${pkgs.coreutils}/bin/cp -a ${plugin.src} "$plugin_tmp"
          ${pkgs.coreutils}/bin/chmod -R u+rwX,g+rwX,o-rwx "$plugin_tmp"
          printf '%s\n' ${lib.escapeShellArg plugin.version} > "$plugin_tmp/.nix-managed"
          ${pkgs.coreutils}/bin/chown -R ${toString ids.hermes}:${toString ids.hermes} "$plugin_tmp"
          ${pkgs.coreutils}/bin/rm -rf -- "$plugin_target"
          ${pkgs.coreutils}/bin/mv "$plugin_tmp" "$plugin_target"
        '') managedPlugins}
      '';
    };

    docker-hindsight = {
      after = [ "microvm-install-keys.service" ];
      requires = [ "microvm-install-keys.service" ];
      unitConfig.RequiresMountsFor = paths.root;
    };

    docker-hermes = {
      after = [
        "docker-hindsight.service"
        "hermes-bootstrap.service"
        "microvm-install-keys.service"
      ];
      requires = [
        "docker-hindsight.service"
        "hermes-bootstrap.service"
        "microvm-install-keys.service"
      ];
      serviceConfig.ExecStartPre = lib.mkAfter [ waitForHindsight ];
      unitConfig.RequiresMountsFor = paths.root;
    };

    hermes-scrub-secret-backups = {
      description = "Remove Hermes dotenv migration backups";
      wantedBy = [ "docker-hermes.service" ];
      after = [ "docker-hermes.service" ];
      requires = [ "docker-hermes.service" ];
      unitConfig.RequiresMountsFor = paths.root;
      serviceConfig.Type = "oneshot";
      script = ''
        set -eu
        for attempt in $(${pkgs.coreutils}/bin/seq 1 120); do
          if ${pkgs.curl}/bin/curl --fail --silent --max-time 2 \
            http://127.0.0.1:9119/ >/dev/null; then
            ${pkgs.findutils}/bin/find ${paths.data} -maxdepth 1 \
              -type f -name '.env.bak-*' -delete
            exit 0
          fi
          ${pkgs.coreutils}/bin/sleep 1
        done
        echo "Hermes dashboard did not become ready before dotenv backup cleanup" >&2
        exit 1
      '';
    };
  };
}
