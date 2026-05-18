_:
{
  services.tailscale = {
    enable = true;
    authKeyFile = "/var/keys/tailscale_key";
    openFirewall = true;
    disableTaildrop = true;
    extraSetFlags = [ "--advertise-routes=" ];
  };
}
