{ pkgs, ... }:

{
  imports = [
    ../../profiles/home/capabilities/minimal.nix
    ../../profiles/home/capabilities/interactive.nix
    ../../profiles/home/capabilities/development.nix
  ];

  home = {
    username = "lightquantum";
    homeDirectory = "/home/lightquantum";
    stateVersion = "25.05";
    sessionPath = [
      "$HOME/.local/bin"
    ];
  };

}
