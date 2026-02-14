{
  inputs,
  lib,
  lqOverlays,
  withSystem,
  ...
}:
let
  hostLib = import ../lib/hosts.nix {
    inherit inputs lib withSystem;
  };

  hosts = import ../hosts/registry.nix {
    inherit inputs lqOverlays;
    inherit (hostLib) mkHmConfigModule;
  };
in
{
  _module.args.lq = {
    inherit hostLib hosts;
  };
}
