{
  inputs,
  lib,
  lqOverlays,
  withSystem,
  ...
}:
let
  inherit (inputs) nixpkgs home-manager nixvim pyproject-nix nur;

  mkHmConfigModule =
    withMac: system: userPathMap:
    let
      lqPkgs = withSystem system ({ config, ... }: config.packages);

      nur-modules = import nur {
        nurpkgs = nixpkgs.legacyPackages.${system};
      };

      sharedModules =
        [
          nixvim.homeManagerModules.nixvim
        ]
        ++ lib.optionals withMac [
          ../../modules/home/darwin/power.nix
          ../../modules/home/darwin/xcompose.nix
          nur-modules.repos.lightquantum.modules.chsh
          nur-modules.repos.lightquantum.modules.wallpaper
        ];
    in
    {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        users = builtins.mapAttrs (_name: path: import path) userPathMap;
        inherit sharedModules;
        extraSpecialArgs = {
          inherit
            system
            nixvim
            pyproject-nix
            lqPkgs
            ;
        };
      };
    };

  hostDefs = {
    mbp = {
      system = "aarch64-darwin";
      darwinModules = [
        lqOverlays.generated
        lqOverlays.texFmt
        lqOverlays.colmena
        lqOverlays.aerospaceMark
        ../../hosts/mbp/system.nix
        home-manager.darwinModules.home-manager
        (mkHmConfigModule true "aarch64-darwin" {
          lightquantum = ../../hosts/mbp/home.nix;
          root = ../../hosts/mbp/home-root.nix;
        })
      ];
      aliases =
        [ "lightquantum-mbp" ]
        ++ builtins.map (n: "lightquantum-mbp-${toString n}") (builtins.genList (x: x + 1) 8);
    };

    meow = {
      system = "x86_64-linux";
      nixosModules = [
        home-manager.nixosModules.home-manager
        ../../hosts/meow/system.nix
        (mkHmConfigModule false "x86_64-linux" {
          lightquantum = ../../hosts/meow/home.nix;
        })
      ];
      legacyName = "lightquantum-meow";
      deploy = {
        targetHost = "meow";
        targetPort = 20422;
        targetUser = "lightquantum";
        buildOnTarget = true;
      };
    };

    orb = {
      system = "aarch64-linux";
      nixosModules = [
        lqOverlays.generated
        home-manager.nixosModules.home-manager
        ../../hosts/orb/system.nix
        (mkHmConfigModule false "aarch64-linux" {
          lightquantum = ../../hosts/orb/home.nix;
        })
      ];
      legacyName = "orbstack-nixos";
      deploy = {
        targetHost = "orb";
        targetUser = "nixos";
        buildOnTarget = true;
      };
    };

    arch = {
      system = "x86_64-linux";
      username = "lightquantum";
      homeModules = [
        lqOverlays.generated
        nixvim.homeManagerModules.nixvim
        ../../modules/home/package-restrictions/stage1.nix
        ../../hosts/arch/home.nix
      ];
      homeStage2Module = ../../modules/home/package-restrictions/stage2.nix;
      legacyName = "lightquantum@lightquantum-arch";
    };
  };
in
{
  _module.args.lq = {
    inherit hostDefs;
  };
}
