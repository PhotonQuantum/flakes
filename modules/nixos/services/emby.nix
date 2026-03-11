{ config, lib, pkgs, ... }:
let
  cfg = config.services.emby;
  needsPrivilegedPortCapability = cfg.port < 1024;
  bindServiceCapabilities =
    if needsPrivilegedPortCapability then
      [ "CAP_NET_BIND_SERVICE" ]
    else
      [ "" ];

  dataDir = cfg.dataDir;
  configDir = "${dataDir}/config";
  systemXml = "${configDir}/system.xml";

  bindReadOnlyPaths = map (dir: "${dir}:${dir}") cfg.mediaDirs;

  xmlPatchPython = pkgs.python3.withPackages (ps: [ ps.lxml ]);

  prepareDataScript = pkgs.writeShellScript "emby-prepare-data" ''
    set -euo pipefail

    install -d -m 0750 -o ${lib.escapeShellArg cfg.user} -g ${lib.escapeShellArg cfg.group} \
      ${lib.escapeShellArg dataDir} \
      ${lib.escapeShellArg configDir}

    ${xmlPatchPython}/bin/python3 <<'PY'
import os
from lxml import etree as ET

system_xml = ${builtins.toJSON systemXml}
port = ${builtins.toJSON (toString cfg.port)}

os.makedirs(os.path.dirname(system_xml), exist_ok=True)

if os.path.exists(system_xml) and os.path.getsize(system_xml) > 0:
    tree = ET.parse(system_xml)
    root = tree.getroot()
else:
    root = ET.Element(
        "ServerConfiguration",
        nsmap = {
          "xsi": "http://www.w3.org/2001/XMLSchema-instance",
          "xsd": "http://www.w3.org/2001/XMLSchema",
        },
    )
    tree = ET.ElementTree(root)

# Preserve the namespace declarations Emby writes on the root element.
desired_nsmap = {
    "xsi": "http://www.w3.org/2001/XMLSchema-instance",
    "xsd": "http://www.w3.org/2001/XMLSchema",
}

if root.nsmap != desired_nsmap:
    new_root = ET.Element(root.tag, nsmap=desired_nsmap)
    for key, value in root.attrib.items():
        new_root.set(key, value)
    new_root.text = root.text
    new_root.tail = root.tail
    for child in root:
        new_root.append(child)
    root = new_root
    tree._setroot(root)

managed_values = {
    "HttpServerPortNumber": port,
    "PublicPort": port,
}

for key, value in managed_values.items():
    elem = root.find(key)
    if elem is None:
        elem = ET.SubElement(root, key)
    elem.text = value

tree.write(system_xml, encoding="utf-8", xml_declaration=True, pretty_print=True)
PY

    chown -R ${lib.escapeShellArg cfg.user}:${lib.escapeShellArg cfg.group} ${lib.escapeShellArg dataDir}
    chmod 0640 ${lib.escapeShellArg systemXml}
  '';

  execStart = lib.escapeShellArg "${cfg.package}/bin/emby";
in
{
  options.services.emby = {
    enable = lib.mkEnableOption "Emby media server";

    package = lib.mkOption {
      type = lib.types.package;
      defaultText = lib.literalExpression "withSystem pkgs.stdenv.hostPlatform.system ({ config, ... }: config.packages.emby)";
      description = "Emby package providing the emby executable.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "emby";
      description = "User account under which Emby runs.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "emby";
      description = "Group account under which Emby runs.";
    };

    createUser = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to create the Emby system user.";
    };

    createGroup = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to create the Emby system group.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the configured Emby HTTP port in the firewall.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8096;
      description = "HTTP port Emby listens on.";
    };

    dataDir = lib.mkOption {
      type = lib.types.coercedTo lib.types.path toString lib.types.str;
      default = "/var/lib/emby";
      description = "Emby program data directory passed via -programdata.";
    };

    mediaDirs = lib.mkOption {
      type = lib.types.listOf (lib.types.coercedTo lib.types.path toString lib.types.str);
      default = [ ];
      description = "Read-only media library directories made visible to the service.";
    };

    extraEnvironment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Additional environment variables for the Emby service.";
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
        home = dataDir;
        createHome = false;
      };
    };

    systemd.tmpfiles.rules = [
      "d ${dataDir} 0750 ${cfg.user} ${cfg.group} - -"
      "d ${configDir} 0750 ${cfg.user} ${cfg.group} - -"
    ];

    systemd.services.emby = {
      description = "Emby Media Server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      path = [ pkgs.coreutils xmlPatchPython ];
      serviceConfig =
        {
          Type = "simple";
          User = cfg.user;
          Group = cfg.group;
          WorkingDirectory = dataDir;
          ExecStartPre = [ prepareDataScript ];
          ExecStart = execStart;
          Restart = "on-failure";
          RestartForceExitStatus = 3;
          RestartSec = 5;
          LimitNOFILE = 65535;
          UMask = "0027";
          NoNewPrivileges = true;
          PrivateTmp = true;
          PrivateMounts = true;
          ProtectSystem = "strict";
          ReadWritePaths = [ dataDir ];
          ProtectControlGroups = true;
          ProtectKernelLogs = true;
          ProtectKernelModules = true;
          ProtectKernelTunables = true;
          ProtectClock = true;
          ProtectProc = "invisible";
          ProcSubset = "pid";
          RestrictNamespaces = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          LockPersonality = true;
          RemoveIPC = true;
          SystemCallArchitectures = "native";
          RestrictAddressFamilies = [
            "AF_UNIX"
            "AF_INET"
            "AF_INET6"
            "AF_NETLINK"
          ];
          CapabilityBoundingSet = bindServiceCapabilities;
          AmbientCapabilities = bindServiceCapabilities;
        }
        // lib.optionalAttrs (bindReadOnlyPaths != [ ]) {
          BindReadOnlyPaths = bindReadOnlyPaths;
        };
      environment = {
        EMBY_DATA = dataDir;
      } // cfg.extraEnvironment;
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
  };
}
