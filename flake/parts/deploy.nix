{ inputs, lq, ... }:
let
  inherit (inputs) nixpkgs colmena;

  meow = lq.hostDefs.meow;
  orb = lq.hostDefs.orb;
in
{
  flake.colmenaHive = colmena.lib.makeHive {
    meta = {
      nixpkgs = import nixpkgs {
        system = "aarch64-darwin";
      };
      nodeNixpkgs = {
        "${meow.legacyName}" = import nixpkgs {
          system = meow.system;
        };
        "${orb.legacyName}" = import nixpkgs {
          system = orb.system;
        };
      };
    };

    "${meow.legacyName}" = {
      deployment = meow.deploy;
      imports = meow.nixosModules;
    };

    "${orb.legacyName}" = {
      deployment = orb.deploy;
      imports = orb.nixosModules;
    };
  };
}
