{ withSystem, ... }:
{
  flake.nixosModules.ani-rss =
    { pkgs, ... }:
    {
      imports = [ ../../modules/nixos/services/ani-rss.nix ];
      services.ani-rss.package = withSystem pkgs.stdenv.hostPlatform.system (
        { config, ... }:
        config.packages."ani-rss"
      );
    };
}
