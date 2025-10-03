# Stage 2 of the package restriction system
# This module is applied via extendModules to avoid infinite recursion
# when filtering home.packages
{ lib, prev, ... }:
let
  # Access the fully evaluated package list from stage 1
  # 'prev' contains the previous evaluation state before this module
  originalPackages = prev.config.home.packages;

  # Filter out packages that are marked for removal
  # This is where the actual package filtering happens
  filteredPackages = lib.filter (
    pkg: !(lib.elem (lib.getName pkg) prev.config.programs.packageRestrictions.removePackages)
  ) originalPackages;
in
{
  config = {
    # Apply the filtered package list using mkForce to override any other definitions
    # This is safe here because we're in a new evaluation context (via extendModules)
    home.packages = lib.mkForce filteredPackages;

    # Set the stage2 flag to true, which changes the validation logic in no-package.nix
    # In stage 2, packages in removePackages list are treated as unauthorized
    programs.packageRestrictions.__stage2 = true;
  };
}
