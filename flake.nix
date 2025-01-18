{
  description = "LightQuantum's Nix Flakes";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nur.url = "github:nix-community/NUR";
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
    tex-fmt = {
      url = "github:WGUNDERWOOD/tex-fmt";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pyproject-nix = {
      url = "github:nix-community/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nh = {
      url = "github:viperML/nh";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nur,
      darwin,
      nixpkgs,
      home-manager,
      nixvim,
      tex-fmt,
      pyproject-nix,
      nh,
      ...
    }:
    let
      generated-overlay = {
        nixpkgs.overlays = [
          (final: prev: {
            generated = (import ./_sources/generated.nix) {
              inherit (final)
                fetchurl
                fetchgit
                fetchFromGitHub
                dockerTools
                ;
            };
          })
        ];
      };
      tex-fmt-overlay = {
        nixpkgs.overlays = [
          tex-fmt.overlays.default
        ];
      };
      nh-overlay = {
        nixpkgs.overlays = [
          nh.overlays.default
        ];
      };
      hm-config =
        system: userPathMap:
        let
          nur-modules = import nur {
            nurpkgs = nixpkgs.legacyPackages.${system};
          };
          hm-modules = [
            nixvim.homeManagerModules.nixvim
            ./modules/power_mac.nix
            ./modules/Xcompose_mac.nix
            nur-modules.repos.lightquantum.modules.chsh
            nur-modules.repos.lightquantum.modules.wallpaper
          ];
          users = builtins.mapAttrs (name: path: import path) userPathMap;
        in
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users = users;
            sharedModules = hm-modules;
            extraSpecialArgs = {
              inherit
                system
                nixvim
                pyproject-nix
                ;
            };
          };
        };
      meow-modules = [
        home-manager.nixosModules.home-manager
        ./meow/configuration.nix
        (hm-config "x86_64-linux" {
          lightquantum = ./meow/home.nix;
        })
      ];
      mbp-modules = [
        generated-overlay
        tex-fmt-overlay
        nh-overlay
        ./mbp/configuration.nix
        home-manager.darwinModules.home-manager
        (hm-config "aarch64-darwin" {
          lightquantum = ./mbp/home.nix;
          root = ./mbp/home-root.nix;
        })
      ];
    in
    {
      nixosConfigurations = {
        lightquantum-meow = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = meow-modules;
        };
      };
      darwinConfigurations =
        let
          conf = darwin.lib.darwinSystem {
            system = "aarch64-darwin";
            modules = mbp-modules;
          };
        in
        {
          lightquantum-mbp = conf;
        }
        // builtins.listToAttrs (
          builtins.map (n: {
            name = "lightquantum-mbp-${toString n}";
            value = conf;
          }) (builtins.genList (x: x + 1) 8)
        );

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
