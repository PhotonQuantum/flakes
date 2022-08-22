{ pkgs, ... }:

{
  home = {
    username = "lightquantum";
    homeDirectory = "/home/lightquantum";
    stateVersion = "22.05";
  };
  programs = {
    home-manager.enable = true;
  };
}
