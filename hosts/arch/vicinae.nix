{ config, pkgs, ... }:

{
  programs.vicinae = {
    enable = true;

    systemd = {
      enable = true;
      autoStart = true;
      target = "graphical-session.target";
    };

    extensions = [
      (config.lib.vicinae.mkExtension {
        name = "nix";
        src = pkgs.generated.vicinae_extensions.src + "/extensions/nix";
      })
      (config.lib.vicinae.mkExtension {
        name = "arch-packages";
        src = pkgs.generated.vicinae_extensions.src + "/extensions/arch-packages";
      })
    ];
  };

  systemd.user.services.vicinae.Service.Environment = [
    "__EGL_VENDOR_LIBRARY_DIRS=/usr/share/glvnd/egl_vendor.d"
    "LD_LIBRARY_PATH=/usr/lib"
  ];
}
