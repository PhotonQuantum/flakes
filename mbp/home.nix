{ pkgs, ... }:

{
  home = {
    username = "lightquantum";
    homeDirectory = "/Users/lightquantum";
    stateVersion = "22.05";
  };
  programs = {
    home-manager.enable = true;
  };
}
