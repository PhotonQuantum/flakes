{ config, ... }:
let
  configOnly = config.home.configOnly or false;
in
{
  imports = [
    ../modules/cli/yazi.nix
    ../modules/vcs/gh.nix
    ../modules/vcs/lazygit.nix
  ];

  programs = {
    lsd.enable = !configOnly;
    htop.enable = !configOnly;

    gh = {
      enable = true;
      settings.aliases = {
        transfer = "api repos/$1/transfer -f new_owner=$2";
      };
    };

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    home-manager.enable = true;
  };
}
