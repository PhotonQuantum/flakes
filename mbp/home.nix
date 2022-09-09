{ pkgs, ... }:

{
  imports = [
    ../common/vim.nix
  ];

  home = {
    username = "lightquantum";
    homeDirectory = "/Users/lightquantum";
    stateVersion = "22.05";
    sessionVariables = {
      PNPM_PATH = "$HOME/Library/pnpm";
    };
    sessionPath = [
        "$HOME/.local/bin"
        "$HOME/opt/GNAT/2020/bin"
        "$HOME/Library/pnpm"
    ];
  };
  programs = {
    aria2.enable = true;
    bat.enable = true;
    lsd.enable = true;
    htop.enable = true;
    lf.enable = true;
    gh.enable = true;
    skim.enable = true;
    opam.enable = true;
    gpg = {
      enable = true;
      scdaemonSettings = {
        disable-ccid = true;
      };
      settings = {
        default-key = "A99DCF320110092028ECAC42E53ED56B7F20B7BB";
        auto-key-retrieve = true;
      };
    };
    topgrade = {
      enable = true;
      package = pkgs.unstable.topgrade;
      settings = {
        assume_yes = true;
        disable = [ "brew" "nix" ];
      };
    };
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    home-manager.enable = true;
    zsh = {
      enable = true;
      shellAliases = {
        vim = "nvim";
        ls = "lsd";
        coqtags = "fd -e v . . ~/.opam/default/lib/coq/theories -X ctags --options=/Users/lightquantum/.config/coq.ctags";
      };
      enableAutosuggestions = true;
      enableSyntaxHighlighting = true;
      oh-my-zsh = {
        enable = true;
        plugins = [ "git" "sudo" "cp" ];
      };
      initExtra = ''
        export FPATH="/opt/homebrew/share/zsh/site-functions${FPATH+:$FPATH}";
        export MANPATH="/opt/homebrew/share/man${MANPATH+:$MANPATH}:";
        export INFOPATH="/opt/homebrew/share/info:${INFOPATH:-}";
        function git-sign {
            FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch --commit-filter 'git commit-tree -S "$@";' $1..HEAD
        }
        function git-delete-bak {
            ref=$(git show-ref | awk '/ refs.original.refs/{print$2}')
            git update-ref -d $ref
        }
      '';
      envExtra = ". $HOME/.cargo/env";
    };
    starship.enable = true;
    lazygit = {
      enable = true;
      settings = {
        gui.showIcons = true;
        refresher.refreshInterval = 1;
      };
    };
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
