# This module implements a two-stage package restriction system to control which
# packages can be installed via Home Manager.
{ lib, config, options, pkgs, ... }:
let
  cfg = config.packageRestrictions;

  # Get the original package list before filtering
  # We check if it's defined to avoid evaluation errors
  originalPackages = if options.home.packages.isDefined
    then config.home.packages
    else [];

  # Extract package names for validation
  installedPackageNames = map lib.getName originalPackages;

  # Determine which packages are unauthorized based on the current stage:
  # - Stage 1 (__stage2 = false): Allow packages in removePackages list temporarily
  #   (they will be filtered out in stage 2)
  # - Stage 2 (__stage2 = true): Treat packages in removePackages as unauthorized
  #   (they should have been filtered out by now)
  unauthorizedPackages = lib.filter
    (if cfg.__stage2
      then (pkg: !(lib.elem pkg cfg.allowedPackages))  # Stage 2: Only allowed packages should remain
      else (pkg: !(lib.elem pkg cfg.allowedPackages) && !(lib.elem pkg cfg.removePackages)))  # Stage 1: Allow both allowed and to-be-removed
    installedPackageNames;

  unauthorizedNames = lib.concatStringsSep ", " unauthorizedPackages;
in
{
  options.packageRestrictions = {
    enable = lib.mkEnableOption "package restrictions" // {
      default = false;
      description = "Enable package restriction checks";
    };

    allowedPackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = [ "git" "vim" "htop" ];
      description = "List of package names that are allowed to be installed";
    };

    removePackages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = [ "unwanted-dep" "bloat-tool" ];
      description = "List of package names to remove from the final package set, even if they would otherwise be included";
    };

    # Internal option used by the two-stage evaluation system
    # Do not set this manually - it's controlled by stage2.nix
    __stage2 = lib.mkOption {
      type = lib.types.bool;
      default = false;
      internal = true;
      description = "Internal flag to indicate stage 2 of package filtering";
    };
  };

  config = lib.mkIf cfg.enable {
    # NOTE: The actual package filtering happens in stage2.nix
    # We don't filter here to avoid infinite recursion when reading config.home.packages
    # home.packages = lib.mkForce filteredPackages;  # <- This would cause infinite recursion

    # Build-time assertion to ensure only authorized packages are present
    # The check logic changes based on the stage:
    # - Stage 1: Validates that packages are either allowed OR marked for removal
    # - Stage 2: Validates that only allowed packages remain (removal should be complete)
    assertions = [{
      assertion = unauthorizedPackages == [];
      message = "Home Manager: unauthorized packages found. Disallowed: ${unauthorizedNames}. Allowed packages: ${lib.concatStringsSep ", " cfg.allowedPackages}. Packages to remove: ${lib.concatStringsSep ", " cfg.removePackages}";
    }];
  };
}
