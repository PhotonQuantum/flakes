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

  flake.nixosModules.emby =
    { pkgs, ... }:
    {
      imports = [ ../../modules/nixos/services/emby.nix ];
      services.emby.package = withSystem pkgs.stdenv.hostPlatform.system (
        { config, ... }:
        config.packages.emby
      );
    };
}
