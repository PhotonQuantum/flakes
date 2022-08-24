{ pkgs, ... }:

{
  home = {
    username = "lightquantum";
    homeDirectory = "/Users/lightquantum";
    stateVersion = "22.05";
  };
  programs = {
    home-manager.enable = true;
    lazygit.enable = true;
    git = {
      enable = true;
      lfs.enable = true;
      userName = "LightQuantum";
      userEmail = "self@lightquantum.me";
      signing = {
        key = "A99DCF320110092028ECAC42E53ED56B7F20B7BB";
        signByDefault = true;
      };
      ignores = [
        "/.idea"
      ];
      extraConfig = {
        pull.ff = "only";
        push.autoSetupRemote = true;
        absorb.maxStack = 50;
      };
    };
  };
}
