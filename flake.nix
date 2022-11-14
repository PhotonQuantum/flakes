{
  description = "LightQuantum's Nix Flakes";

  inputs = {
    # nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs.url = "github:NixOS/nixpkgs/428f22c3596f5bf0b3f1a0e3308816baf99a3fc8";
    nur.url = github:nix-community/NUR;
    darwin = {
      # Manage darwin systems
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      # Manage per-user config globally
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim = {
      url = "github:pta2002/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    colmena = {
      # Deploy to remote systems
      url = "github:zhaofengli/colmena";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.stable.follows = "nixpkgs";
    };
  };

  outputs = { self, nur, darwin, nixpkgs, home-manager, nixvim, ... }@inputs:
    let
      hm-config = system: path:
        let
          nur-modules = import nur {
            nurpkgs = nixpkgs.legacyPackages.${system};
          };
          hm-modules = [
            nixvim.homeManagerModules.nixvim
            nur-modules.repos.lightquantum.modules.chsh
            nur-modules.repos.lightquantum.modules.wallpaper
          ];
        in
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users.lightquantum = import path;
            sharedModules = hm-modules;
            extraSpecialArgs = { inherit nixvim; };
          };
        };
      meow-modules = [
        home-manager.nixosModules.home-manager
        ./meow/configuration.nix
        (hm-config "x86_64-linux" ./meow/home.nix)
      ];
      mbp-modules = [
        nur.nixosModules.nur
        ./mbp/configuration.nix
        home-manager.darwinModules.home-manager
        (hm-config "aarch64-darwin" ./mbp/home.nix)
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
          inputs = { inherit darwin nixpkgs home-manager; };
          system = "aarch64-darwin";
          modules = mbp-modules;
          specialArgs = { inherit inputs; };
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
