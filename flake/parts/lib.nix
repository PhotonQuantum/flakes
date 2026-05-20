{
  inputs,
  lib,
  withSystem,
  ...
}:
let
  hostLib = import ../lib/hosts.nix {
    inherit inputs lib withSystem;
  };

  hosts = import ../hosts/registry.nix {
    inherit inputs;
    inherit (hostLib) mkHmConfigModule;
  };
  microvmInventory = import ../../hosts/homelab/microvms/inventory.nix { inherit inputs lib; };
in
{
  _module.args.lq = {
    inherit hostLib hosts;
  };

  flake.homelab.tailscale = microvmInventory.tailscale;
  flake.homelab.beszel = microvmInventory.beszel;
}
