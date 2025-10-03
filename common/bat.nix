{ config, pkgs, ... }:
let
  configOnly = config.home.configOnly or false;
in {
  programs.bat = {
    enable = true;
    package = if configOnly then pkgs.emptyDirectory else pkgs.bat;
    config = {
      theme = "base16";
    };
  };
}