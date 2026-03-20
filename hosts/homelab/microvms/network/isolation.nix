{
  lib,
  homelabSecrets,
  resolvedGroups,
}:
let
  allGroupConfigs = builtins.attrValues resolvedGroups;
  noHostAccessInterfaces = lib.unique (
    map (group: group.bridgeName) (
      builtins.filter (group: !group.networkPolicy.hostAccess) allGroupConfigs
    )
  );
  noLanAccessInterfaces = lib.unique (
    map (group: group.bridgeName) (
      builtins.filter (group: !group.networkPolicy.lanAccess) allGroupConfigs
    )
  );

  privateIPv4Cidrs = [
    "10.0.0.0/8"
    "172.16.0.0/12"
    "192.168.0.0/16"
    "169.254.0.0/16"
    "100.64.0.0/10"
  ];

  privateIPv6Cidrs = [
    "fc00::/7"
    "fe80::/10"
    "ff00::/8"
  ];

  noHostAccessCommands = lib.concatMapStrings (bridgeName: ''
    # Block guests from reaching host services on any port when host access is disabled.
    iptables -w -I nixos-fw 1 -i '${bridgeName}' -j DROP
    ip6tables -w -I nixos-fw 1 -i '${bridgeName}' -j DROP
  '') noHostAccessInterfaces;

  noLanAccessCommands =
    let
      mkPrivateForwardDropCommands =
        bridgeName:
        lib.concatMapStrings (
          cidr: "iptables -w -I nixos-filter-forward 1 -i '${bridgeName}' -d '${cidr}' -j DROP\n"
        ) (lib.reverseList privateIPv4Cidrs);
      mkPrivateForwardDropCommands6 =
        bridgeName:
        lib.concatMapStrings (
          cidr: "ip6tables -w -I nixos-filter-forward 1 -i '${bridgeName}' -d '${cidr}' -j DROP\n"
        ) (lib.reverseList privateIPv6Cidrs);
    in
    lib.concatMapStrings (bridgeName: ''
      # Keep internet access but block local/private destinations when LAN access is disabled.
      iptables -w -I nixos-filter-forward 1 -i '${bridgeName}' -j DROP
      iptables -w -I nixos-filter-forward 1 -i '${bridgeName}' -o '${homelabSecrets.uplinkName}' -j ACCEPT
      ${mkPrivateForwardDropCommands bridgeName}

      # Mirror internet-only behavior for IPv6 forwarding as well.
      ip6tables -w -I nixos-filter-forward 1 -i '${bridgeName}' -j DROP
      ip6tables -w -I nixos-filter-forward 1 -i '${bridgeName}' -o '${homelabSecrets.uplinkName}' -j ACCEPT
      ${mkPrivateForwardDropCommands6 bridgeName}
    '') noLanAccessInterfaces;
in
{
  networking.firewall.extraCommands = noHostAccessCommands;
  networking.nat.extraCommands = noLanAccessCommands;
}
