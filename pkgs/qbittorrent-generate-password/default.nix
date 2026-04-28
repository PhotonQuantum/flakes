{
  git,
  qbittorrent-password,
  writeShellApplication,
}:

writeShellApplication {
  name = "qbittorrent-generate-password";

  runtimeInputs = [
    git
    qbittorrent-password
  ];

  text = builtins.readFile ./qbittorrent-generate-password;
}
