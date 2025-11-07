{ ... }:
{
  imports = [
    ./basic.nix
    ./marks.nix
    ./special-workspace.nix
  ];

  services.jankyborders = {
    enable = true;
    settings = {
      active_color = "0xccf52891";
      inactive_color = "0xff494d64";
      ax_focus = true;
      hidpi = true;
      width = 7.5;
    };
  };

  programs.aerospace = {
    enable = true;
    launchd = {
      enable = true;
      keepAlive = true;
    };
  };
}
