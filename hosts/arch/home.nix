{ pkgs, lib, lqPkgs, ... }:

{
  imports = [
    ../../profiles/home/capabilities/minimal.nix
    ../../profiles/home/capabilities/interactive.nix
    ../../profiles/home/capabilities/graphics.nix
    ../../profiles/home/capabilities/development.nix
    ./walker.nix
    ./hyprland.nix
    ./darkman.nix
    ./toshy.nix
    ../../secrets/ssh.nix
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

      shell.enableShellIntegration = true;

      # This is the key flag that tells modules to generate configs only
      configOnly = true;
    };

    home.sessionPath = [
      "$HOME/.local/bin"
      "$HOME/.pnpm"
    ];
    home.sessionVariables = {
      EDITOR = "nvim";
      PNPM_HOME = "$HOME/.pnpm";
    };

    home.packages = with pkgs; [
      nixfmt
      nil
      nvfetcher
      lqPkgs.denix
      sketchybar-app-font
      devenv
    ];

    fonts.fontconfig.enable = true;

    programs = {
      # Do not generate any man page.
      man.enable = false;

      # Let Home Manager install and manage itself when in standalone mode
      home-manager.enable = true;

      # It would be better to let nix manage nix related tools.
      nh.enable = true;
      direnv = {
        enable = true;
        nix-direnv.enable = true;
      };

      fish = {
        shellAliases = {
          ls = "lsd";
          fpf = "env SHELL=/usr/bin/bash fpf";
        };
      };

      ghostty = {
        settings = {
          font-size = 12;
        };
      };
    };

    # Do not include any package except explicitly listed.
    packageRestrictions = {
      enable = true;
      allowedPackages = [
        "empty-directory"

        # home-manager
        "home-manager"
        "home-configuration-reference-manpage"
        "hm-session-vars.sh"
        "hm-session-vars.fish"

        # xdg-mime needed for generating desktop entries
        "shared-mime-info"
        "dummy-xdg-mime-dirs1"
        "dummy-xdg-mime-dirs2"

        # nix managed programs
        "direnv"
        "nh"
        "nixfmt"
        "nil"
        "nvfetcher"
        "devenv"

        # vim is managed by nixvim
        "nixvim"

        "denix"
        "sketchybar-app-font"
        "dummy-fc-dir1"
        "dummy-fc-dir2"
      ];
      removePackages = [
        "bat"
        "fish"
      ];
    };
  };
}
