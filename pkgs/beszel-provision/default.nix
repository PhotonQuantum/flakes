{
  coreutils,
  jq,
  nix,
  openssh,
  openssl,
  writeShellApplication,
}:

writeShellApplication {
  name = "beszel-provision";
  runtimeInputs = [
    coreutils
    jq
    nix
    openssh
    openssl
  ];
  text = builtins.readFile ./beszel-provision;
}
