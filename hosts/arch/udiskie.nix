{
  systemd.user.services.udiskie = {
    Unit = {
      Description = "Automounter for removable media";
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      Type = "simple";
      ExecStart = "/usr/bin/udiskie --smart-tray";
      Restart = "on-failure";
    };

    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
