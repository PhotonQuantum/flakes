{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages = import ../../pkgs { inherit pkgs; };
    };
}
