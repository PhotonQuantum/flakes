{
  inputs,
  lq,
  ...
}:
let
  inherit (inputs) nixpkgs colmena;
  deployHosts = lq.hostLib.selectDeployHosts lq.hosts;
in
{
  flake.colmenaHive = colmena.lib.makeHive (
    {
      meta = {
        nixpkgs = import nixpkgs {
          system = "aarch64-darwin";
        };
        nodeNixpkgs = lq.hostLib.mkDeployNodeNixpkgs {
          hosts = deployHosts;
        };
        specialArgs = { inherit inputs; };
      };
    }
    // lq.hostLib.mkDeployNodes { hosts = deployHosts; }
  );
}
