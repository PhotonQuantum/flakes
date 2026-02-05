{ pkgs, ... }:

{
  imports = [
    ../../common/vim.nix
    ../../common/starship.nix
    ../../common/yazi.nix
    ../../common/fish.nix
    ../../common/git.nix
  ];

  home = {
    username = "lightquantum";
    homeDirectory = "/home/lightquantum";
    stateVersion = "25.05";
    sessionPath = [
      "$HOME/.local/bin"
    ];
  };

  programs = {
    lsd.enable = true;
    htop.enable = true;
    gh = {
      enable = true;
      settings = {
        aliases = {
          "transfer" = "api repos/$1/transfer -f new_owner=$2";
        };
      };
    };
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    home-manager.enable = true;
    lazygit = {
      enable = true;
      settings = {
        gui.showIcons = true;
        refresher.refreshInterval = 1;
      };
    };
  };
}
