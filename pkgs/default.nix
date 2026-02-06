{ pkgs }:
{
  denix = pkgs.callPackage ./denix { };
  "validate-cam-imports" = pkgs.callPackage ./validate-cam-imports { };
  "gen-compose" = pkgs.callPackage ./gen-compose { };
}
