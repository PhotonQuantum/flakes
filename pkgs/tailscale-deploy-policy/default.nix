{
  hujsonfmt,
  jq,
  nix,
  tailscale-gitops-pusher,
  writeShellApplication,
}:

writeShellApplication {
  name = "tailscale-deploy-policy";
  runtimeInputs = [
    hujsonfmt
    jq
    nix
    tailscale-gitops-pusher
  ];
  text = builtins.readFile ./tailscale-deploy-policy;
}
