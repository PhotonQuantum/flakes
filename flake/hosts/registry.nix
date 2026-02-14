{
  inputs,
  lqOverlays,
  mkHmConfigModule,
}:
let
  inherit (inputs) home-manager nixvim disko;
in
{
  mbp = {
    system = "aarch64-darwin";
    names =
      [ "mbp" "lightquantum-mbp" ]
      ++ builtins.map (n: "lightquantum-mbp-${toString n}") (builtins.genList (x: x + 1) 8);
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
  };

  meow = {
    system = "x86_64-linux";
    names = [
      "meow"
      "lightquantum-meow"
    ];
    nixosModules = [
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
    nixosModules = [
      disko.nixosModules.disko
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
    nixosModules = [
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
