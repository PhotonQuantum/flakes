{ inputs, ... }:
{
  perSystem =
    { inputs', system, ... }:
    let
      pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      packages = import ../../pkgs { inherit inputs' pkgs; };
    };
}
