{
  inputs,
  lqOverlays,
  mkHmConfigModule,
}:
let
  inherit (inputs) colmena determinate disko home-manager microvm nixvim;
  colmenaNixosModules = [
    colmena.nixosModules.assertionModule
    colmena.nixosModules.keyChownModule
    colmena.nixosModules.keyServiceModule
    colmena.nixosModules.deploymentOptions
  ];
in
{
  mbp = {
    system = "aarch64-darwin";
    names =
      [ "mbp" "lightquantum-mbp" ]
      ++ builtins.map (n: "lightquantum-mbp-${toString n}") (builtins.genList (x: x + 1) 8);
    darwinModules = [
      determinate.darwinModules.default
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
  };

  meow = {
    system = "x86_64-linux";
    names = [
      "meow"
      "lightquantum-meow"
    ];
    nixosModules = colmenaNixosModules ++ [
      home-manager.nixosModules.home-manager
      ../../hosts/meow/system.nix
      (mkHmConfigModule false "x86_64-linux" {
        lightquantum = ../../hosts/meow/home.nix;
      })
    ];
    nixosDeploy = {
      targetHost = "meow";
      targetPort = 20422;
      targetUser = "lightquantum";
      buildOnTarget = true;
    };
  };

  homelab = {
    system = "x86_64-linux";
    names = [
      "homelab"
    ];
    nixosModules = colmenaNixosModules ++ [
      disko.nixosModules.disko
      microvm.nixosModules.host
      ../../hosts/homelab/system.nix
    ];
    nixosDeploy = {
      targetHost = "lightquantum-homelab.local";
      targetUser = "lightquantum";
      buildOnTarget = false;
    };
  };

  orb = {
    system = "aarch64-linux";
    names = [
      "orb"
      "orbstack-nixos"
    ];
    nixosModules = colmenaNixosModules ++ [
      lqOverlays.generated
      home-manager.nixosModules.home-manager
      ../../hosts/orb/system.nix
      (mkHmConfigModule false "aarch64-linux" {
        lightquantum = ../../hosts/orb/home.nix;
      })
    ];
    nixosDeploy = {
      targetHost = "orb";
      targetUser = "nixos";
      buildOnTarget = true;
    };
  };

  arch = {
    system = "x86_64-linux";
    names = [
      "lightquantum@arch"
      "lightquantum@lightquantum-arch"
    ];
    homeModules = [
      determinate.homeManagerModules.default
      lqOverlays.colmena
      lqOverlays.generated
      nixvim.homeModules.nixvim
      ../../modules/home/package-restrictions/stage1.nix
      ../../hosts/arch/home.nix
    ];
    homeExtendFn =
      { prev, ... }:
      prev.extendModules {
        modules = [ ../../modules/home/package-restrictions/stage2.nix ];
        specialArgs = {
          inherit prev;
        };
      };
  };
}
