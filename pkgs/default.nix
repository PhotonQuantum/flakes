{ inputs', pkgs }:
let
  inherit (pkgs) lib;
  generated = (import ../_sources/generated.nix) {
    inherit (pkgs)
      fetchurl
      fetchgit
      fetchFromGitHub
      dockerTools
      ;
  };
  qbittorrent-password = inputs'.qbittorrent-password.packages.default or null;
in
{
  denix = pkgs.callPackage ./denix { };
  "validate-cam-imports" = pkgs.callPackage ./validate-cam-imports { };
  "gen-compose" = pkgs.callPackage ./gen-compose { };
  "tailscale-deploy-policy" = pkgs.callPackage ./tailscale-deploy-policy { };
  "tailscale-provision-auth-keys" = pkgs.callPackage ./tailscale-provision-auth-keys { };
  "ani-rss" = pkgs.callPackage ./ani-rss { inherit generated; };
  emby = pkgs.callPackage ./emby { inherit generated; };
}
// lib.optionalAttrs (qbittorrent-password != null) {
  "qbittorrent-generate-password" = pkgs.callPackage ./qbittorrent-generate-password {
    inherit qbittorrent-password;
  };
}
