{ config, pkgs, ... }:
let
  configOnly = config.home.configOnly or false;
in {
  programs.lazygit = {
    enable = true;
    package = if configOnly then pkgs.emptyDirectory else pkgs.lazygit;
    settings = {
      gui.showIcons = true;
      refresher.refreshInterval = 1;
    };
  };
}