{ inputs, ... }:
{
  perSystem =
    { inputs', pkgs, system, ... }:
    {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      packages = import ../../pkgs { inherit inputs' pkgs; };
    };
}
