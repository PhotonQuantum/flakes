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
    home-manager = {
      # Manage per-user config globally
      url = "github:nix-community/home-manager/release-22.05"; # Need to match nixpkgs channel
      inputs.nixpkgs.follows = "nixpkgs";
    };
    malob = {
      # malob modules. Necessary for security-pam.
      url = "github:malob/nixpkgs";
      inputs.nixpkgs-unstable.follows = "nixpkgs-unstable";
      inputs.darwin.follows = "darwin";
      inputs.home-manager.follows = "home-manager";
    };
    nixvim = {
      url = "github:pta2002/nixvim";
    };
    colmena = {
      # Deploy to remote systems
      url = "github:zhaofengli/colmena";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, darwin, home-manager, nixvim, nixpkgs, ... }@inputs:
    let
      meow-modules = [
        home-manager.nixosModules.home-manager
        ./meow/configuration.nix
        {
          home-manager = {
            # Enable home-manager
            useGlobalPkgs = true;
            useUserPackages = true;
            users.lightquantum = import ./meow/home.nix;
            sharedModules = [
              nixvim.homeManagerModules.nixvim
            ];
          };
        }
      ];
    in
    {
      nixosConfigurations = {
        lightquantum-meow = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = meow-modules;
        };
      };
      darwinConfigurations = {
        lightquantum-mbp = darwin.lib.darwinSystem {
          inherit inputs;
          system = "aarch64-darwin";
          modules = [
            ./mbp/configuration.nix
            inputs.malob.darwinModules.security-pam # might get merged to nix-darwin in the future
            home-manager.darwinModules.home-manager
            {
              home-manager = {
                # Enable home-manager
                useGlobalPkgs = true;
                useUserPackages = true;
                users.lightquantum = import ./mbp/home.nix;
              };
            }
          ];
        };
      };

      colmena = {
        meta = {
          nixpkgs = import nixpkgs {
            system = "x86_64-linux";
          };
        };
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
