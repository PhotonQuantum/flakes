_: {
  programs.git = {
    enable = true;
    difftastic = {
      enable = true;
      display = "inline";
    };
    lfs.enable = true;
    userName = "LightQuantum";
    userEmail = "self@lightquantum.me";
    ignores = [
      "/.idea"
      ".DS_Store"
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