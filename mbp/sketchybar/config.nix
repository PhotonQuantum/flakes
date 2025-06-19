{ pkgs, ... }:
{
  fonts = {
    packages = with pkgs; [
      sketchybar-app-font
    ];
  };

  services.sketchybar = {
    enable = true;
    extraPackages = [
      pkgs.aerospace
    ];
  };
}
