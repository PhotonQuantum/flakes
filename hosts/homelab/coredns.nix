{ ... }:
{
  services.coredns = {
    enable = true;
    config = builtins.readFile ./coredns/Corefile;
  };

  environment.etc."coredns/db.home.arpa".source = ./coredns/db.home.arpa;

  networking.firewall.interfaces.tailscale0 = {
    allowedUDPPorts = [ 53 ];
    allowedTCPPorts = [ 53 ];
  };
}
