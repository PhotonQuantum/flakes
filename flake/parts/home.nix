{ inputs, lq, ... }:
let
  inherit (inputs) home-manager nixpkgs nixvim pyproject-nix;

  arch = lq.hostDefs.arch;

  archConf =
    let
      hmConf = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = arch.system;
          config.allowUnfree = true;
        };
        modules = arch.homeModules;
        extraSpecialArgs = {
          inherit nixvim pyproject-nix;
        };
      };
    in
    hmConf.extendModules {
      modules = [ arch.homeStage2Module ];
      specialArgs = {
        prev = hmConf;
      };
    };
in
{
  flake.homeConfigurations = {
    "${arch.username}@arch" = archConf;
    "${arch.legacyName}" = archConf;
  };
}
