{ pkgs, lib, ... }:
{
  xdg.configFile."sketchybar" = {
    source = ./config;
    recursive = true;
    onChange = "${lib.getExe pkgs.sketchybar} --reload";
  };
  xdg.configFile."sketchybar/helpers/app_icons.lua" = with pkgs.generated; {
    source = sketchybar_app_font.src;
    onChange = "${lib.getExe pkgs.sketchybar} --reload";
  };
  xdg.configFile."sketchybar/sketchybarrc" = {
    text = ''
      #!/usr/bin/env ${lib.getExe pkgs.lua54Packages.lua}

      package.cpath = package.cpath .. ";${pkgs.sbarlua}/lib/?.so"

      -- Load the sketchybar-package and prepare the helper binaries
      require("helpers")
      require("init")
    '';
    executable = true;
    onChange = "${lib.getExe pkgs.sketchybar} --reload";
  };
}
