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

  home.file = with pkgs; let
    format = pkgs.formats.toml { };
  in
  {
    ".cargo/config".source = format.generate "config" {
      build.rustc-wrapper = "${sccache}/bin/sccache";
      target.x86_64-apple-darwin.rustflags = [ "-C" "link-arg=-fuse-ld=${zld}/bin/zld" ];
      target.aarch64-apple-darwin.rustflags = [ "-C" "link-arg=-fuse-ld=${zld}/bin/zld" ];
    };
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
    nix-index.enable = true;
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
      package = pkgs.topgrade;
      settings = {
        assume_yes = true;
        disable = [ "brew_cask" "brew_formula" "mas" "nix" "shell" "node" ];
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
      enableSyntaxHighlighting = true;
      enableAutosuggestions = true;
      plugins = [
        {
          name = "input";
          file = "init.zsh";
          src = pkgs.fetchFromGitHub {
            owner = "zimfw";
            repo = "input";
            rev = "{{ commit_of_github('zimfw', 'input', 'master') }}";
            sha256 = "{{ hash_from_github('zimfw', 'input', 'master') }}";
          };
        }
        {
          name = "completion";
          file = "init.zsh";
          src = pkgs.fetchFromGitHub {
            owner = "zimfw";
            repo = "completion";
            rev = "{{ commit_of_github('zimfw', 'completion', 'master') }}";
            sha256 = "{{ hash_from_github('zimfw', 'completion', 'master') }}";
          };
        }
        {
          name = "git";
          file = "init.zsh";
          src = pkgs.fetchFromGitHub {
            owner = "zimfw";
            repo = "git";
            rev = "{{ commit_of_github('zimfw', 'git', 'master') }}";
            sha256 = "{{ hash_from_github('zimfw', 'git', 'master') }}";
          };
        }
        {
          name = "utility";
          file = "init.zsh";
          src = pkgs.fetchFromGitHub {
            owner = "zimfw";
            repo = "utility";
            rev = "{{ commit_of_github('zimfw', 'utility', 'master') }}";
            sha256 = "{{ hash_from_github('zimfw', 'utility', 'master') }}";
          };
        }
        {
          name = "zsh-completions";
          src = pkgs.fetchFromGitHub {
            owner = "zsh-users";
            repo = "zsh-completions";
            rev = "{{ commit_of_github('zsh-users', 'zsh-completions', 'master') }}";
            sha256 = "{{ hash_from_github('zsh-users', 'zsh-completions', 'master') }}";
          };
        }
        {
          name = "you-should-use";
          src = "${pkgs.zsh-you-should-use}/share/zsh/plugins/you-should-use";
        }
      ];
      initExtra = ''
        export FPATH="/opt/homebrew/share/zsh/site-functions''${FPATH+:$FPATH}";
        export MANPATH="/opt/homebrew/share/man''${MANPATH+:$MANPATH}:";
        export INFOPATH="/opt/homebrew/share/info:''${INFOPATH:-}";
        function git-sign {
            FILTER_BRANCH_SQUELCH_WARNING=1 git filter-branch --commit-filter 'git commit-tree -S "$@";' $1..HEAD
        }
        function git-delete-bak {
            ref=$(git show-ref | awk '/ refs.original.refs/{print$2}')
            git update-ref -d $ref
        }
        lfcd () {
            tmp="$(mktemp)"
            lf -last-dir-path="$tmp" "$@"
            if [ -f "$tmp" ]; then
                dir="$(cat "$tmp")"
                rm -f "$tmp"
                if [ -d "$dir" ]; then
                    if [ "$dir" != "$(pwd)" ]; then
                        cd "$dir"
                    fi
                fi
            fi
        }
        autoload -U select-word-style
        select-word-style bash
      '';
      envExtra = ". $HOME/.cargo/env";
    };
    starship = {
      enable = true;
      settings = {
        git_status.disabled = true;
      };
    };
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
        ".DS_Store"
      ];
      extraConfig = {
        pull.ff = "only";
        push.autoSetupRemote = true;
        absorb.maxStack = 50;
      };
    };
  };
}