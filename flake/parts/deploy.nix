{
  inputs,
  lq,
  withSystem,
  ...
}:
let
  inherit (inputs) colmena;
  deployHosts = lq.hostLib.selectDeployHosts lq.hosts;
in
{
  flake.colmenaHive = colmena.lib.makeHive (
    {
      meta = {
        nixpkgs = withSystem "aarch64-darwin" ({ pkgs, ... }: pkgs);
        nodeNixpkgs = lq.hostLib.mkDeployNodeNixpkgs {
          hosts = deployHosts;
        };
        specialArgs = { inherit inputs; };
      };
    }
    // lq.hostLib.mkDeployNodes { hosts = deployHosts; }
  );
}
