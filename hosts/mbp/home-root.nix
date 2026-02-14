_:

{
  imports = [
    ../../profiles/home/modules/editor/vim/minimal.nix
    ../../secrets/ssh.nix
  ];

  home = {
    username = "root";
    homeDirectory = "/var/root";
    stateVersion = "22.05";
  };

  programs = {
    ssh.enable = true;
  };
}
