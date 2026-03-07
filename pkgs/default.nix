{ pkgs }:
let
  generated = (import ../_sources/generated.nix) {
    inherit (pkgs)
      fetchurl
      fetchgit
      fetchFromGitHub
      dockerTools
      ;
  };
in
{
  denix = pkgs.callPackage ./denix { };
  "validate-cam-imports" = pkgs.callPackage ./validate-cam-imports { };
  "gen-compose" = pkgs.callPackage ./gen-compose { };
  "ani-rss" = pkgs.callPackage ./ani-rss { inherit generated; };
}
