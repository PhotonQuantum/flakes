{ inputs, lib, ... }:
let
  homelabSecrets = import ../../secrets/homelab.nix;
  microvmInventory = import ./microvms/inventory.nix { inherit inputs lib; };
in
{
  deployment.keys = lib.mapAttrs' (
    _: node:
    let
      keyName = "tailscale_${node.name}_authkey";
    in
    {
      name = keyName;
      value = {
        keyFile = "${homelabSecrets.tailscaleAuthKeyDir}/${node.name}.authkey";
        destDir = "/var/keys";
        user = "microvm";
        group = "kvm";
        permissions = "0400";
      };
    }
  ) microvmInventory.tailscale.nodes;
}
