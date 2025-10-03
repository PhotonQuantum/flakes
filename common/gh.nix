{ config, pkgs, ... }:
let
  configOnly = config.home.configOnly or false;
in {
  programs.gh = {
    enable = true;
    package = if configOnly then pkgs.emptyDirectory else pkgs.gh;
    settings = {
      # Add any default gh settings here if needed
      git_protocol = "ssh";
      prompt = "enabled";
    };
  };
}