{ pkgs, ... }:
{
  nixpkgs.overlays = [
    (final: prev: {
      sbarlua = prev.callPackage ./sbarlua.nix { };
    })
  ];

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
