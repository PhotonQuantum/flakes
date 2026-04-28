{ moduleWithSystem, ... }:
{
  flake.nixosModules.ani-rss = moduleWithSystem (
    { config, ... }:
    { ... }:
    {
      imports = [ ../../modules/nixos/services/ani-rss.nix ];
      services.ani-rss.package = config.packages."ani-rss";
    }
  );

  flake.nixosModules.emby = moduleWithSystem (
    { config, ... }:
    { ... }:
    {
      imports = [ ../../modules/nixos/services/emby.nix ];
      services.emby.package = config.packages.emby;
    }
  );
}
