{ config, pkgs, ... }:
let
  configOnly = config.home.configOnly or false;
in
{
  programs.codex = {
    enable = true;
    package = if configOnly then null else pkgs.ghostty;
    settings = {
      features = {
        web_search_request = true;
        ghost_commit = true;
      };
      tui = {
        notifications = true;
      };
    };
  };
}
