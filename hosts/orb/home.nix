{ pkgs, ... }:

{
  imports = [
    ../../common/vim.nix
    ../../common/starship.nix
    ../../common/yazi.nix
    ../../common/fish.nix
    ../../common/git.nix
    ../../common/lazygit.nix
    ../../profiles/common/home/interactive-tools.nix
  ];

  home = {
    username = "lightquantum";
    homeDirectory = "/home/lightquantum";
    stateVersion = "25.05";
    sessionPath = [
      "$HOME/.local/bin"
    ];
  };

}
