{
  inputs,
  lib,
  withSystem,
}:
let
  inherit (inputs)
    darwin
    home-manager
    nixpkgs
    nixvim
    nur
    pyproject-nix
    ;
in
rec {
  namesFor =
    hostName: def: if def ? names && builtins.length def.names > 0 then def.names else [ hostName ];

  canonicalNameFor = hostName: def: builtins.head (namesFor hostName def);

  aliasNamesFor =
    hostName: def:
    let
      names = namesFor hostName def;
    in
    if builtins.length names > 1 then builtins.tail names else [ ];

  selectDarwinHosts = hosts: lib.filterAttrs (_name: def: def ? darwinModules) hosts;

  selectNixosHosts = hosts: lib.filterAttrs (_name: def: def ? nixosModules) hosts;

  selectHomeHosts = hosts: lib.filterAttrs (_name: def: def ? homeModules) hosts;

  selectDeployHosts =
    hosts: lib.filterAttrs (_name: def: def ? nixosModules && def ? nixosDeploy) hosts;

  mkHmConfigModule =
    withMac: system: userPathMap:
    let
      nur-modules = import nur {
        nurpkgs = nixpkgs.legacyPackages.${system};
      };

      sharedModules = [
        nixvim.homeModules.nixvim
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
            inputs
            nixvim
            pyproject-nix
            system
            ;
        };
      };
    };

  mkDarwinConfig =
    hostName: def:
    withSystem def.system (
      { config, pkgs, ... }:
      let
        base = darwin.lib.darwinSystem {
          system = def.system;
          modules = [
            { nixpkgs.pkgs = pkgs; }
          ]
          ++ def.darwinModules;
        };
      in
      if def ? darwinExtendFn then
        def.darwinExtendFn {
          inherit
            config
            hostName
            inputs
            lib
            ;
          hostDef = def;
          prev = base;
          system = def.system;
        }
      else
        base
    );

  mkNixosConfig =
    hostName: def:
    withSystem def.system (
      { config, pkgs, ... }:
      let
        base = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit inputs;
          };
          modules = [
            nixpkgs.nixosModules.readOnlyPkgs
            { nixpkgs.pkgs = pkgs; }
          ]
          ++ def.nixosModules;
        };
      in
      if def ? nixosExtendFn then
        def.nixosExtendFn {
          inherit
            config
            hostName
            inputs
            lib
            ;
          hostDef = def;
          prev = base;
          system = def.system;
        }
      else
        base
    );

  mkHomeConfig =
    hostName: def:
    withSystem def.system (
      { config, pkgs, ... }:
      let
        base = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = def.homeModules;
          extraSpecialArgs = {
            inherit nixvim pyproject-nix;
          };
        };
      in
      if def ? homeExtendFn then
        def.homeExtendFn {
          inherit
            config
            hostName
            inputs
            lib
            ;
          hostDef = def;
          prev = base;
          system = def.system;
        }
      else
        base
    );

  mkNamedConfigurations =
    {
      hosts,
      build,
    }:
    let
      hostNames = builtins.attrNames hosts;
      builtByHost = lib.mapAttrs build hosts;

      canonicalEntries = builtins.map (hostName: {
        name = canonicalNameFor hostName hosts.${hostName};
        value = builtByHost.${hostName};
      }) hostNames;

      aliasEntries = lib.concatMap (
        hostName:
        builtins.map (alias: {
          name = alias;
          value = builtByHost.${hostName};
        }) (aliasNamesFor hostName hosts.${hostName})
      ) hostNames;
    in
    builtins.listToAttrs (canonicalEntries ++ aliasEntries);

  mkDeployNodeNixpkgs =
    {
      hosts,
    }:
    builtins.listToAttrs (
      lib.concatMap (
        hostName:
        let
          def = hosts.${hostName};
          nodePkgs = withSystem def.system ({ pkgs, ... }: pkgs);
        in
        builtins.map (nodeName: {
          name = nodeName;
          value = nodePkgs;
        }) (namesFor hostName def)
      ) (builtins.attrNames hosts)
    );

  mkDeployNodes =
    {
      hosts,
    }:
    builtins.listToAttrs (
      lib.concatMap (
        hostName:
        let
          def = hosts.${hostName};
          nodeValue = {
            deployment = def.nixosDeploy;
            imports = def.nixosModules;
          };
        in
        builtins.map (nodeName: {
          name = nodeName;
          value = nodeValue;
        }) (namesFor hostName def)
      ) (builtins.attrNames hosts)
    );
}
