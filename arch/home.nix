{ pkgs, lib, ... }:

{
  imports = [
    ../common/starship.nix
    ../common/yazi.nix
    ../common/fish.nix
    ../common/git.nix
  ];

  # Define configOnly as a module option that our modules can check
  options.home.configOnly = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Whether to generate configs only without installing packages";
  };

  config = {
    home = {
      username = "lightquantum";
      homeDirectory = "/home/lightquantum";
      stateVersion = "24.05";

      # This is the key flag that tells modules to generate configs only
      configOnly = true;
    };

    # Minimal set of packages - just home-manager itself
    home.packages = [ ];

    # Do not generate any man page.
    programs.man.enable = false;

    # Let Home Manager install and manage itself when in standalone mode
    programs.home-manager.enable = true;

    # Do not include any package except explicitly listed.
    programs.packageRestrictions = {
      enable = true;
      allowedPackages = [
        "empty-directory"

        # home-manager
        "home-manager"
        "home-configuration-reference-manpage"
        "hm-session-vars.sh"

        # xdg-mime needed for generating desktop entries
        "shared-mime-info"
        "dummy-xdg-mime-dirs1"
        "dummy-xdg-mime-dirs2"
      ];
      removePackages = [
        "fish"
      ];
    };
  };
}