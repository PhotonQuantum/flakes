{ config, lib, ... }:

let
  configOnly = config.home.configOnly or false;
in
{
  config = lib.mkMerge [
    (lib.mkIf configOnly {
      programs.fish.interactiveShellInit = ''
        zoxide init fish | source
      '';
    })
    (lib.mkIf (!configOnly) {
      programs.zoxide = {
        enable = true;
        enableFishIntegration = true;
      };
    })
  ];
}
