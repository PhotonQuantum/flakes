{
  curl,
  jq,
  nix,
  writeShellApplication,
}:

writeShellApplication {
  name = "tailscale-deploy-services";
  runtimeInputs = [
    curl
    jq
    nix
  ];
  text = builtins.readFile ./tailscale-deploy-services;
}
