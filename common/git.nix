{ config, pkgs, ... }:
let
  configOnly = config.home.configOnly or false;
in {
  programs.git = {
    enable = true;
    package = if configOnly then pkgs.emptyDirectory else pkgs.git;
    difftastic = {
      enable = !configOnly;
      display = "inline";
    };
    lfs.enable = !configOnly;
    userName = "LightQuantum";
    userEmail = "self@lightquantum.me";
    ignores = [
      "/.idea"
      ".DS_Store"
      "**/.claude/settings.local.json"
    ];
    extraConfig = {
      pull.ff = "only";
      init.defaultBranch = "master";
      push.autoSetupRemote = true;
      absorb.maxStack = 50;
      merge.tool = "nvimdiff";
      core.autocrlf = "input";
    };
  };
}