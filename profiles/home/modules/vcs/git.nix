{ config, pkgs, ... }:
let
  configOnly = config.home.configOnly or false;
in
{
  programs.difftastic = {
    enable = !configOnly;
    options.display = "inline";
    git.enable = !configOnly;
  };
  programs.git = {
    enable = true;
    package = if configOnly then pkgs.emptyDirectory else pkgs.git;
    lfs.enable = !configOnly;
    ignores = [
      "/.idea"
      ".DS_Store"
      "**/.claude/settings.local.json"
    ];
    settings = {
      user = {
        name = "LightQuantum";
        email = "self@lightquantum.me";
      };
      pull.ff = "only";
      init.defaultBranch = "master";
      push.autoSetupRemote = true;
      absorb.maxStack = 50;
      merge.tool = "nvimdiff";
      core.autocrlf = "input";
    };
  };
}
