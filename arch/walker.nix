{
  pkgs,
  lib,
  config,
  ...
}:
let
  inherit (lib) optional;
  inherit (lib.modules) mkIf;
  tomlFormat = pkgs.formats.toml { };

  elephantConfig = { };
  walkerConfig = { };
in
{
  xdg.configFile."elephant/elephant.toml" = mkIf (elephantConfig != { }) {
    source = (pkgs.formats.toml { }).generate "elephant.toml" elephantConfig;
  };
  systemd.user.services.elephant = {
    Unit = {
      Description = "Elephant launcher backend";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };

    Service = {
      Type = "simple";
      ExecStart = "/usr/bin/elephant";
      Restart = "on-failure";
      RestartSec = 1;

      # Clean up socket on stop
      ExecStopPost = "/usr/bin/rm -f /tmp/elephant.sock";
    };

    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  xdg.configFile."walker/config.toml" = mkIf (walkerConfig != { }) ({
    source = tomlFormat.generate "walker-config.toml" walkerConfig;
  });

  systemd.user.services.walker = {
    Unit = {
      Description = "Walker - Application Runner";
      ConditionEnvironment = "WAYLAND_DISPLAY";
      After = [
        "graphical-session.target"
        "elephant.service"
      ];
      Requires = [ "elephant.service" ];
      PartOf = [ "graphical-session.target" ];
      # X-Restart-Triggers =
      # if walkerConfig != { } then [ "${config.xdg.configFile."walker/config.toml".source}" ] else [ ];
    };
    Service = {
      ExecStart = "/usr/bin/walker --gapplication-service";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
