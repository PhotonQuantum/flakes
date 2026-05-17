{
  services.tailscale = {
    enable = true;
    authKeyFile = "/var/keys/tailscale-auth-key";
    openFirewall = true;
  };
}
