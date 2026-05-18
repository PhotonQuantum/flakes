{
  config,
  lib,
  pkgs,
  ...
}:
let
  auxModel = "google/gemini-flash-latest";
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
    provider = "openrouter";
    model = auxModel;
  };
  hermesSettings = {
    model = {
      provider = "openrouter";
      base_url = "https://openrouter.ai/api/v1";
      default = "google/gemini-pro-latest";
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

  services.hermes-agent = {
    enable = true;
    container = {
      enable = true;
      backend = "docker";
      extraOptions = [ "--pid=host" ];
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
      install -D -o hermes -g hermes -m 0640 ${hermesConfig} /var/lib/hermes/.hermes/config.yaml
      install -D -o hermes -g hermes -m 0640 ${hindsightConfig} /var/lib/hermes/.hermes/hindsight/config.json

      install -o hermes -g hermes -m 0640 /dev/null /var/lib/hermes/.hermes/.env
      cat /var/keys/hermes.env > /var/lib/hermes/.hermes/.env
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
    };

    serviceConfig = {
      User = "hermes";
      Group = "hermes";
      WorkingDirectory = "/var/lib/hermes/workspace";
      ExecStart = "${hermesPackage}/bin/hermes dashboard --host 127.0.0.1 --port 9119 --no-open --tui";
      Restart = "on-failure";
      RestartSec = "5s";
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
