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
    hostName: def:
    if def ? names && builtins.length def.names > 0 then def.names else [ hostName ];

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
      lqPkgs = withSystem system ({ config, ... }: config.packages);

      nur-modules = import nur {
        nurpkgs = nixpkgs.legacyPackages.${system};
      };

      sharedModules =
        [
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
            lqPkgs
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
      { config, ... }:
      let
        base = darwin.lib.darwinSystem {
          system = def.system;
          specialArgs = {
            lqPkgs = config.packages;
          };
          modules = def.darwinModules;
        };
      in
      if def ? darwinExtendFn then
        def.darwinExtendFn {
          inherit config hostName inputs lib;
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
      { config, ... }:
      let
        base = nixpkgs.lib.nixosSystem {
          system = def.system;
          specialArgs = {
            inherit inputs;
            lqPkgs = config.packages;
          };
          modules = def.nixosModules;
        };
      in
      if def ? nixosExtendFn then
        def.nixosExtendFn {
          inherit config hostName inputs lib;
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
      { config, ... }:
      let
        base = home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            system = def.system;
            config.allowUnfree = true;
          };
          modules = def.homeModules;
          extraSpecialArgs = {
            inherit nixvim pyproject-nix;
            lqPkgs = config.packages;
          };
        };
      in
      if def ? homeExtendFn then
        def.homeExtendFn {
          inherit config hostName inputs lib;
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
          nodePkgs = import nixpkgs {
            system = def.system;
          };
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
