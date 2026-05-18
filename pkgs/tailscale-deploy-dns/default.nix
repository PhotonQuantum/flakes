{ curl, jq, nix, writeShellApplication }:

writeShellApplication {
  name = "tailscale-deploy-dns";
  runtimeInputs = [
    curl
    jq
    nix
  ];
  text = builtins.readFile ./tailscale-deploy-dns;
}
