{ inputs, ... }:
let
  inherit (inputs) tex-fmt colmena aerospace-mark;
in
{
  _module.args.lqOverlays = {
    generated = {
      nixpkgs.overlays = [
        (final: _prev: {
          generated = (import ../../_sources/generated.nix) {
            inherit (final)
              fetchurl
              fetchgit
              fetchFromGitHub
              dockerTools
              ;
          };
        })
      ];
    };

    texFmt = {
      nixpkgs.overlays = [ tex-fmt.overlays.default ];
    };

    colmena = {
      nixpkgs.overlays = [ colmena.overlays.default ];
    };

    aerospaceMark = {
      nixpkgs.overlays = [
        (final: _prev: {
          aerospace-marks = aerospace-mark.packages.${final.stdenv.hostPlatform.system}.default;
        })
      ];
    };
  };
}
