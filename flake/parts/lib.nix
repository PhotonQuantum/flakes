{
  inputs,
  lib,
  withSystem,
  ...
}:
let
  hostLib = import ../lib/hosts.nix {
    inherit inputs lib withSystem;
  };

  hosts = import ../hosts/registry.nix {
    inherit inputs;
    inherit (hostLib) mkHmConfigModule;
  };
in
{
  _module.args.lq = {
    inherit hostLib hosts;
  };
}
