{ lib, pkgs, ... }:
let
  homelabSecrets = import ../../../../secrets/homelab.nix;
  domain = homelabSecrets.tailscaleDns.domain;
in
{
  services.resolved.enable = lib.mkForce false;

  services.coredns = {
    enable = true;
    package = pkgs.coredns-with-tailscale;
    config = ''
      ${domain}:53 {
        errors
        log
        tailscale ${domain}
      }
    '';
  };

  systemd.services.coredns = {
    after = [
      "tailscaled.service"
      "tailscaled-autoconnect.service"
      "tailscaled-set.service"
    ];
    wants = [ "tailscaled.service" ];
    serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "root";
      Group = "root";
    };
  };

  networking.firewall.interfaces.tailscale0 = {
    allowedUDPPorts = [ 53 ];
    allowedTCPPorts = [ 53 ];
  };
}
