{ pkgs, lib, ... }:
with lib;
let
  yamlFormat = pkgs.formats.yaml { };

  generateScripts =
    folder:
    mapAttrs' (
      k: v: {
        name = "${folder}/${k}";
        value = {
          source =
            if builtins.isPath v || isDerivation v then
              v
            else
              pkgs.writeShellScript (hm.strings.storeFileName k) v;
        };
      }
    );
in
let
  settings = {
    usegeoclue = true;
  };
  darkModeScripts = {
    "desktop-notification.sh" = ''
      #!/usr/bin/env bash
      notify-send --app-name="darkman" --urgency=low --icon=weather-clear-night "switching to dark mode"
    '';
    "gtk4.sh" = ''
      #!/usr/bin/env bash
      gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"
    '';
  };
  lightModeScripts = {
    "desktop-notification.sh" = ''
      #!/usr/bin/env bash
      notify-send --app-name="darkman" --urgency=low --icon=weather-clear "switching to light mode"
    '';
    "gtk4.sh" = ''
      #!/usr/bin/env bash
      gsettings set org.gnome.desktop.interface color-scheme "prefer-light"
    '';
   };
in
{
  xdg.configFile = {
    "darkman/config.yaml" = mkIf (settings != { }) {
      source = yamlFormat.generate "darkman-config.yaml" settings;
    };
  };

  xdg.dataFile = mkMerge [
    (mkIf (darkModeScripts != { }) (generateScripts "dark-mode.d" darkModeScripts))
    (mkIf (lightModeScripts != { }) (generateScripts "light-mode.d" lightModeScripts))
  ];

  home.activation.darkmanSystemdUnit = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    PATH="$PATH:/usr/bin" $DRY_RUN_CMD systemctl --user enable darkman.service
  '';
}
