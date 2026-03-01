{ ... }:
{
  services.tg3-bot = {
    enable = true;
    stateDir = "/mnt/tg3-rs";
    environmentFile = "/var/keys/tg3-rs.env";
    extraEnvironment = {
      RUST_LOG = "info";
    };
  };
}
