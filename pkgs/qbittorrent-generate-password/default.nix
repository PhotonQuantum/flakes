{
  git,
  openssl,
  qbittorrent-password,
  writeShellApplication,
}:

writeShellApplication {
  name = "qbittorrent-generate-password";

  runtimeInputs = [
    git
    openssl
    qbittorrent-password
  ];

  text = builtins.readFile ./qbittorrent-generate-password;
}
