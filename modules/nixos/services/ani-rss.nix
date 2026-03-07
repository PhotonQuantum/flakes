{ config, lib, pkgs, ... }:
let
  cfg = config.services.ani-rss;

  jsonFormat = pkgs.formats.json { };
  managedConfig = jsonFormat.generate "ani-rss-managed-config.json" cfg.settings;

  mergeConfigScript = pkgs.writeShellScript "ani-rss-merge-config" ''
    set -euo pipefail

    config_dir=${lib.escapeShellArg cfg.configDir}
    config_file="$config_dir/config.v2.json"
    tmp_file="$config_file.tmp"
    managed_config=${lib.escapeShellArg managedConfig}

    install -d -m 0750 -o ${lib.escapeShellArg cfg.user} -g ${lib.escapeShellArg cfg.group} "$config_dir"

    if [ -f "$config_file" ]; then
      ${pkgs.jq}/bin/jq -n \
        --slurpfile existing "$config_file" \
        --slurpfile managed "$managed_config" \
        '($existing[0] * $managed[0])' > "$tmp_file"
    else
      cp "$managed_config" "$tmp_file"
    fi

    chown ${lib.escapeShellArg cfg.user}:${lib.escapeShellArg cfg.group} "$tmp_file"
    chmod 0640 "$tmp_file"
    mv -f "$tmp_file" "$config_file"
  '';
in
{
  options.services.ani-rss = {
    enable = lib.mkEnableOption "ani-rss service";

    package = lib.mkOption {
      type = lib.types.package;
      defaultText = lib.literalExpression "withSystem pkgs.stdenv.hostPlatform.system ({ config, ... }: config.packages.\"ani-rss\")";
      description = "ani-rss package providing the ani-rss executable.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "ani-rss";
      description = "User account under which ani-rss runs.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "ani-rss";
      description = "Group account under which ani-rss runs.";
    };

    createUser = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to create the ani-rss system user.";
    };

    createGroup = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to create the ani-rss system group.";
    };

    configDir = lib.mkOption {
      type = lib.types.coercedTo lib.types.path toString lib.types.str;
      default = "/var/lib/ani-rss";
      description = "Writable directory for ani-rss runtime state and config.v2.json.";
    };

    serverAddress = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "Value for SERVER_ADDRESS environment variable.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 7789;
      description = "Value for SERVER_PORT environment variable.";
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Declarative JSON fragment merged into config.v2.json before start.";
    };

    extraEnvironment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional environment variables for ani-rss service.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open firewall for ani-rss port.";
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups = lib.mkIf cfg.createGroup {
      "${cfg.group}" = { };
    };

    users.users = lib.mkIf cfg.createUser {
      "${cfg.user}" = {
        isSystemUser = true;
        group = cfg.group;
        home = cfg.configDir;
        createHome = false;
      };
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.configDir} 0750 ${cfg.user} ${cfg.group} - -"
    ];

    systemd.services.ani-rss = {
      description = "ANI-RSS";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      path = [ pkgs.coreutils pkgs.jq ];
      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.configDir;
        ExecStartPre = [ mergeConfigScript ];
        ExecStart = "${cfg.package}/bin/ani-rss";
        Restart = "on-failure";
        RestartSec = 30;
        LimitNOFILE = 65535;
      };
      environment = {
        SERVER_ADDRESS = cfg.serverAddress;
        SERVER_PORT = toString cfg.port;
        CONFIG = cfg.configDir;
      } // cfg.extraEnvironment;
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
  };
}
