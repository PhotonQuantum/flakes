{
  inputs,
  lib,
  lq,
  withSystem,
  ...
}:
let
  inherit (inputs) nixpkgs darwin;

  mkDarwin =
    _name: def:
    withSystem def.system (
      { config, ... }:
      darwin.lib.darwinSystem {
        system = def.system;
        specialArgs = {
          lqPkgs = config.packages;
        };
        modules = def.darwinModules;
      }
    );

  mkNixos =
    _name: def:
    withSystem def.system (
      { config, ... }:
      nixpkgs.lib.nixosSystem {
        system = def.system;
        specialArgs = {
          lqPkgs = config.packages;
        };
        modules = def.nixosModules;
      }
    );

  darwinHosts = lib.filterAttrs (_name: def: def ? darwinModules) lq.hostDefs;
  nixosHosts = lib.filterAttrs (_name: def: def ? nixosModules) lq.hostDefs;

  canonicalDarwin = lib.mapAttrs mkDarwin darwinHosts;
  canonicalNixos = lib.mapAttrs mkNixos nixosHosts;

  mbpAliases = builtins.listToAttrs (
    builtins.map (alias: {
      name = alias;
      value = canonicalDarwin.mbp;
    }) lq.hostDefs.mbp.aliases
  );

  nixosAliases = builtins.listToAttrs (
    builtins.map
      (name: {
        name = lq.hostDefs.${name}.legacyName;
        value = canonicalNixos.${name};
      })
      (builtins.attrNames nixosHosts)
  );
in
{
  flake = {
    darwinConfigurations = canonicalDarwin // mbpAliases;
    nixosConfigurations = canonicalNixos // nixosAliases;
  };
}
