{ curl, jq, nix, writeShellApplication }:

writeShellApplication {
  name = "tailscale-provision-auth-keys";
  runtimeInputs = [
    curl
    jq
    nix
  ];
  text = builtins.readFile ./tailscale-provision-auth-keys;
}
