{
  config,
  ...
}:
{
  services.tailscale = {
    enable = true;
    authKeyFile = "/var/keys/tailscale-auth-key";
    extraUpFlags = [ "--hostname=${config.networking.hostName}" ];
    extraSetFlags = [ "--hostname=${config.networking.hostName}" ];
    openFirewall = true;
  };
}
