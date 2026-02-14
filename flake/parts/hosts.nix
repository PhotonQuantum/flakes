{
  lq,
  ...
}:
let
  darwinHosts = lq.hostLib.selectDarwinHosts lq.hosts;
  nixosHosts = lq.hostLib.selectNixosHosts lq.hosts;

  darwinConfigurations = lq.hostLib.mkNamedConfigurations {
    hosts = darwinHosts;
    build = lq.hostLib.mkDarwinConfig;
  };

  nixosConfigurations = lq.hostLib.mkNamedConfigurations {
    hosts = nixosHosts;
    build = lq.hostLib.mkNixosConfig;
  };
in
{
  flake = {
    inherit darwinConfigurations nixosConfigurations;
  };
}
