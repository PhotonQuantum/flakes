{
  description = "LightQuantum's Nix Flakes";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-22.05"; # Using stable nix channel to avoid surprises.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable"; # malob requires this
    darwin = {
      # Manage darwin systems
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    darwin-unstable = {
      # Manage darwin systems
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    home-manager = {
      # Manage per-user config globally
      url = "github:nix-community/home-manager/release-22.05"; # Need to match nixpkgs channel
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager-unstable = {
      # Manage per-user config globally
      url = "github:nix-community/home-manager"; # Need to match nixpkgs channel
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    nixvim = {
      url = "github:pta2002/nixvim";
    };
    colmena = {
      # Deploy to remote systems
      url = "github:zhaofengli/colmena";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lq = {
      url = "github:PhotonQuantum/nix-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixvim, lq, ... }@inputs:
    let
      hm-modules = [
        nixvim.homeManagerModules.nixvim
      ];
      hm-config = path:
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users.lightquantum = import path;
            sharedModules = hm-modules;
          };
        };
      overlays-module =
        let
          overlay-unstable = final: prev: {
            unstable = inputs.nixpkgs-unstable.legacyPackages.${prev.system};
          };
        in
        { config, pkgs, ... }: {
          nixpkgs.overlays = [
            # overlay-unstable
            lq.overlay
          ];
        };
      with-env = unstable: f:
        let
          nixpkgs = if unstable then inputs.nixpkgs-unstable else inputs.nixpkgs;
          home-manager = if unstable then inputs.home-manager-unstable else inputs.home-manager;
          darwin = if unstable then inputs.darwin-unstable else inputs.darwin;
        in
        f { inherit nixpkgs home-manager darwin; };
      meow-modules = with-env false ({ home-manager, ... }: [
        home-manager.nixosModules.home-manager
        ./meow/configuration.nix
        (hm-config ./meow/home.nix)
      ]);
      # mbp-modules = [
      #   overlays-module
      #   home-manager.darwinModules.home-manager
      #   ./mbp/configuration.nix
      #   (hm-config ./mbp/home.nix)
      # ];
    in
    {
      nixosConfigurations = {
        lightquantum-meow = with-env false ({ nixpkgs, ... }: nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = meow-modules;
        });
      };
      darwinConfigurations = {
        lightquantum-mbp = with-env true ({ darwin, nixpkgs, home-manager }:
          darwin.lib.darwinSystem {
            inputs = { inherit darwin nixpkgs home-manager; };
            system = "aarch64-darwin";
            modules =
              [
                overlays-module
                ./mbp/configuration.nix
                home-manager.darwinModules.home-manager
                {
                  home-manager = {
                    # Enable home-manager
                    useGlobalPkgs = true;
                    useUserPackages = true;
                    users.lightquantum = import ./mbp/home.nix;
                    sharedModules = [
                      nixvim.homeManagerModules.nixvim
                    ];
                  };
                }
              ];
          });
      };

      colmena = {
        meta = with-env false ({ nixpkgs, ... }: {
          nixpkgs = import nixpkgs {
            system = "x86_64-linux";
          };
        });
        lightquantum-meow = {
          deployment = {
            targetHost = "meow";
            targetPort = 20422;
            targetUser = "lightquantum";
            buildOnTarget = true;
          };
          imports = meow-modules;
        };
      };
    };
}
