{ pkgs, ... }:

{
  programs.nixvim = {
    enable = true;
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
}