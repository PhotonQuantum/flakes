{
  lq,
  ...
}:
let
  homeHosts = lq.hostLib.selectHomeHosts lq.hosts;
  homeConfigurations = lq.hostLib.mkNamedConfigurations {
    hosts = homeHosts;
    build = lq.hostLib.mkHomeConfig;
  };
in
{
  flake.homeConfigurations = homeConfigurations;
}
