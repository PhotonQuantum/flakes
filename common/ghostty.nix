{ config, pkgs, lib, ... }:
let
  configOnly = config.home.configOnly or false;
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin or false;
in {
  programs.ghostty = {
    enable = true;
    # On macOS, managed by homebrew; on Linux, use nixpkgs or system package
    package = if isDarwin || configOnly then null else pkgs.ghostty;
    settings = {
      font-family = "Sarasa Term SC";
      font-size = 16;
      theme = "dark:Catppuccin Mocha,light:Catppuccin Latte";
      background-opacity = 0.8;
      background-blur-radius = 80;
      shell-integration-features = true;
    } // lib.optionalAttrs isDarwin {
      # macOS-specific keybinds
      keybind = "global:super+,=toggle_quick_terminal";
      quick-terminal-animation-duration = 0.1;
    };
  };
}