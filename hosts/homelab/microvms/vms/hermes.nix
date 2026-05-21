{
  config,
  lib,
  pkgs,
  ...
}:
let
  auxModel = "~google/gemini-flash-latest";
  hindsightRuntimeVersion = "0.6.2";
  hindsightRuntimeMarker = "${hindsightRuntimeVersion}-3";
  hindsightPythonPathHost = "/var/lib/hermes/.hermes/hindsight-python";
  hindsightPythonPathContainer = "/data/.hermes/hindsight-python";
  hindsightUvCache = "/var/lib/hermes/.hermes/uv-cache";
  hindsightLibraryPath = lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib ];
  extraDependencyGroups = [
    "firecrawl"
    "hindsight"
    "messaging"
    "pty"
    "web"
  ];
  hermesPackage = config.services.hermes-agent.package.override {
    inherit extraDependencyGroups;
  };
  hermesLcmPlugin = pkgs.generated.hermes_lcm.src;
  mkAux = {
    provider = "openrouter-compat";
    model = auxModel;
  };
  hermesSettings = {
    providers.openrouter-compat = {
      name = "openrouter-compat";
      base_url = "https://openrouter.ai/api/v1";
      key_env = "OPENROUTER_API_KEY";
      api_mode = "chat_completions";
    };

    model = {
      provider = "openrouter-compat";
      default = "~google/gemini-pro-latest";
    };

    auxiliary = {
      vision = mkAux;
      web_extract = mkAux;
      compression = mkAux;
      curator = mkAux;
      session_search = mkAux;
      title_generation = mkAux;
      approval = mkAux;
      skills_hub = mkAux;
      mcp = mkAux;
      triage_specifier = mkAux;
    };

    memory = {
      provider = "hindsight";
      memory_enabled = true;
      user_profile_enabled = true;
    };

    web = {
      search_backend = "firecrawl";
      extract_backend = "firecrawl";
    };

    streaming = {
      enabled = true;
      transport = "auto";
      edit_interval = 0.8;
      buffer_threshold = 24;
      fresh_final_after_seconds = 60;
    };

    plugins.enabled = [
      "disk-cleanup"
      "hermes-lcm"
    ];

    context.engine = "lcm";

    security.allow_lazy_installs = true;
  };
  hermesConfig = pkgs.writeText "hermes-config.yaml" (builtins.toJSON hermesSettings);
  hindsightConfig = pkgs.writeText "hermes-hindsight-config.json" (
    builtins.toJSON {
      mode = "local_embedded";
      llm_provider = "openrouter";
      llm_base_url = "https://openrouter.ai/api/v1";
      llm_model = auxModel;
      bank_id = "hermes";
      recall_budget = "mid";
      memory_mode = "hybrid";
      auto_recall = true;
      auto_retain = true;
      idle_timeout = 0;
    }
  );
in
{
  imports = [
    (import ./caddy-proxy.nix { upstream = "http://127.0.0.1:9119"; })
  ];

  users.users.hermes.uid = 998;
  users.groups.hermes.gid = 998;

  services.hermes-agent = {
    enable = true;
    container = {
      enable = true;
      backend = "docker";
      extraOptions = [
        "--pid=host"
        "--env-file=/var/lib/hermes/.hermes/.env"
        "--env=PYTHONPATH=${hindsightPythonPathContainer}"
        "--env=LD_LIBRARY_PATH=${hindsightLibraryPath}"
        "--env=HINDSIGHT_API_EMBEDDINGS_PROVIDER=local"
        "--env=HINDSIGHT_API_RERANKER_PROVIDER=rrf"
      ];
    };
    stateDir = "/var/lib/hermes";
    workingDirectory = "/var/lib/hermes/workspace";
    addToSystemPackages = true;
    environmentFiles = [ "/var/keys/hermes.env" ];
    inherit extraDependencyGroups;
    extraPlugins = [ hermesLcmPlugin ];
    settings = hermesSettings;
  };

  systemd.services.hermes-agent = {
    after = [ "microvm-install-keys.service" ];
    requires = [ "microvm-install-keys.service" ];
    preStart = lib.mkBefore ''
      install -d -o hermes -g hermes -m 2770 /var/lib/hermes/.hermes
      install -d -o hermes -g hermes -m 2770 /var/lib/hermes/.hermes/hindsight
      install -d -o hermes -g hermes -m 2770 /var/lib/hermes/.hermes/plugins
      install -d -o hermes -g hermes -m 2770 /var/lib/hermes/home
      install -d -o hermes -g hermes -m 2770 /var/lib/hermes/home/.hindsight
      install -d -o hermes -g hermes -m 2770 /var/lib/hermes/home/.hindsight/profiles
      install -d -o hermes -g hermes -m 2770 /var/lib/hermes/home/.pg0
      install -d -o hermes -g hermes -m 2770 /var/lib/hermes/home/.cache
      chown -hR hermes:hermes /var/lib/hermes/home/.hindsight /var/lib/hermes/home/.pg0 /var/lib/hermes/home/.cache
      install -D -o hermes -g hermes -m 0640 ${hermesConfig} /var/lib/hermes/.hermes/config.yaml
      install -D -o hermes -g hermes -m 0640 ${hindsightConfig} /var/lib/hermes/.hermes/hindsight/config.json
      install -D -o hermes -g hermes -m 0640 /var/keys/hermes.SOUL.md /var/lib/hermes/.hermes/SOUL.md
      if [ ! -e "${hindsightPythonPathHost}/.hindsight-embedded-runtime-${hindsightRuntimeMarker}" ]; then
        rm -rf "${hindsightPythonPathHost}.tmp"
        install -d -o hermes -g hermes -m 2770 "${hindsightPythonPathHost}.tmp"
        install -d -o hermes -g hermes -m 2770 "${hindsightUvCache}"
        UV_CACHE_DIR="${hindsightUvCache}" ${pkgs.uv}/bin/uv pip install \
          --python ${hermesPackage.hermesVenv}/bin/python \
          --target "${hindsightPythonPathHost}.tmp" \
          --python-preference only-system \
          "hindsight-api-slim[embedded-db]==${hindsightRuntimeVersion}" \
          "hindsight-embed==${hindsightRuntimeVersion}" \
          "hindsight-client==0.6.1" \
          "einops>=0.8.2" \
          "safetensors>=0.6.2" \
          "sentence-transformers>=3.3.0" \
          "torch>=2.6.0" \
          "transformers>=4.53.0"
        UV_CACHE_DIR="${hindsightUvCache}" ${pkgs.uv}/bin/uv pip install \
          --python ${hermesPackage.hermesVenv}/bin/python \
          --target "${hindsightPythonPathHost}.tmp" \
          --python-preference only-system \
          --no-deps \
          "hindsight-all==${hindsightRuntimeVersion}"
        rm -rf "${hindsightPythonPathHost}"
        mv "${hindsightPythonPathHost}.tmp" "${hindsightPythonPathHost}"
        touch "${hindsightPythonPathHost}/.hindsight-embedded-runtime-${hindsightRuntimeMarker}"
        chown -hR hermes:hermes "${hindsightPythonPathHost}"
        find "${hindsightPythonPathHost}" -type d -exec chmod u+rwx,g+rwx,o-rwx {} +
        find "${hindsightPythonPathHost}" -type f -exec chmod u+rw,g+rw,o-rwx {} +
      fi
      rm -rf "${hindsightUvCache}"
      find /var/lib/hermes/.hermes/plugins -maxdepth 1 -type l -name 'nix-managed-*' -delete 2>/dev/null || true
      ${lib.concatStringsSep "\n" (
        map (plugin: ''
          if [ ! -f "${plugin}/plugin.yaml" ]; then
            echo "ERROR: Hermes plugin '${plugin}' has no plugin.yaml" >&2
            exit 1
          fi
          ln -sfn ${plugin} /var/lib/hermes/.hermes/plugins/nix-managed-${lib.getName plugin}
          chown -h hermes:hermes /var/lib/hermes/.hermes/plugins/nix-managed-${lib.getName plugin}
        '') config.services.hermes-agent.extraPlugins
      )}

      install -o hermes -g hermes -m 0640 /dev/null /var/lib/hermes/.hermes/.env
      cat /var/keys/hermes.env > /var/lib/hermes/.hermes/.env
      {
        echo HINDSIGHT_API_EMBEDDINGS_PROVIDER=local
        echo HINDSIGHT_API_RERANKER_PROVIDER=rrf
      } >> /var/lib/hermes/.hermes/.env
    '';
  };

  systemd.services.hermes-dashboard = {
    description = "Hermes Agent Dashboard";
    wantedBy = [ "multi-user.target" ];
    after = [
      "network-online.target"
      "hermes-agent.service"
    ];
    wants = [ "network-online.target" ];
    requires = [ "hermes-agent.service" ];

    environment = {
      HOME = "/var/lib/hermes";
      HERMES_HOME = "/var/lib/hermes/.hermes";
      HERMES_MANAGED = "true";
      MESSAGING_CWD = "/var/lib/hermes/workspace";
      PYTHONPATH = hindsightPythonPathHost;
      LD_LIBRARY_PATH = hindsightLibraryPath;
      HINDSIGHT_API_EMBEDDINGS_PROVIDER = "local";
      HINDSIGHT_API_RERANKER_PROVIDER = "rrf";
    };

    serviceConfig = {
      User = "hermes";
      Group = "hermes";
      WorkingDirectory = "/var/lib/hermes/workspace";
      ExecStart = "${hermesPackage}/bin/hermes dashboard --host 127.0.0.1 --port 9119 --no-open --tui";
      Restart = "on-failure";
      RestartSec = "5s";
      EnvironmentFile = "/var/keys/hermes.env";
      UMask = "0007";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = false;
      ReadWritePaths = [
        "/var/lib/hermes"
        "/var/lib/hermes/workspace"
      ];
      PrivateTmp = true;
    };
  };
}
