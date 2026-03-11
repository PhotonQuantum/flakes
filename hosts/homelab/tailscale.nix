{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  homelabSecrets = import ../../secrets/homelab.nix;
  registry = import ./microvms/registry.nix { inherit inputs; };
  vmLib = import ./microvms/lib.nix { inherit lib; };
  resolvedGroups = vmLib.resolveGroups registry.bridgeGroups;

  microvmRoutes = map
    (group: "${group.ipv4Prefix}.0/${toString group.cidr}")
    (
      builtins.filter
        (group: group.usesManagedSubnet && group.networkPolicy.hostAccess)
        (builtins.attrValues resolvedGroups)
    );
  advertisedRoutes = lib.unique ([ homelabSecrets.lanSubnet ] ++ microvmRoutes);
in
{
  services.tailscale = {
    enable = true;
    authKeyFile = "/var/keys/tailscale_key";
    openFirewall = true;
    disableTaildrop = true;
    useRoutingFeatures = "server";
    extraSetFlags = lib.optionals (advertisedRoutes != [ ]) [
      "--advertise-routes=${lib.concatStringsSep "," advertisedRoutes}"
    ];
  };
  services.networkd-dispatcher = {
    enable = true;
    rules."50-tailscale-optimizations" = {
      onState = [ "routable" ];
      script = ''
        ${pkgs.ethtool}/bin/ethtool -K lan0 rx-udp-gro-forwarding on rx-gro-list off
      '';
    };
  };
}
