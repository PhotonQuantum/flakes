{ pkgs, lib, ... }:
{
  xdg.configFile = {
    "sketchybar" = {
      source = ./.;
      recursive = true;
      onChange = "${lib.getExe pkgs.sketchybar} --reload";
    };
    "sketchybar/helpers/app_icons.lua" = {
      source = "${pkgs.sketchybar-app-font}/lib/sketchybar-app-font/icon_map.lua";
    };
    "sketchybar/sketchybarrc" = {
      executable = true;
      text = ''
          #!/usr/bin/env ${lib.getExe pkgs.lua54Packages.lua}
          package.cpath = package.cpath .. ";${pkgs.lua54Packages.getLuaCPath pkgs.sbarlua}"
          require("helpers")
          require("init")
      '';
    };
  };
}
