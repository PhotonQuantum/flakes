{ pkgs, ... }:

{
  imports = [
    ../common/vim.nix
  ];

  home = {
    username = "lightquantum";
    homeDirectory = "/home/lightquantum";
    stateVersion = "22.05";
  };

  programs = {
    home-manager.enable = true;
    zsh = {
      enable = true;
      shellAliases = {
        vim = "nvim";
      };
      enableSyntaxHighlighting = true;
      oh-my-zsh = {
        enable = true;
      };
    };
    starship.enable = true;
    lazygit.enable = true;
    nixvim = {      enable = true;
      options = {
        number = true;
        relativenumber = true;
        clipboard = "unnamedplus";
      };
      plugins = {
        nix.enable = true;
      };
      extraPlugins = with pkgs.vimPlugins; [
        quick-scope
        suda-vim
      ];
      maps = {
        normal = {
          "H" = { action = "^"; };
          "L" = { action = "$"; };
          "ZA" = { action = ":w suda://%<Return>:q<Return>"; };
        };
        visual = {
          "H" = { action = "^"; };
          "L" = { action = "$"; };
        };
        insert = {
          "<S-CR>" = { action = "<Esc>"; };
        };
        command = {
          "e!!" = { action = "e suda://%"; };
          "r!!" = { action = "e suda://%"; };
          "w!!" = { action = "w suda://%"; };
        };
      };
    };
  };
}
