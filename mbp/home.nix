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

  home.file.".cargo/config".source = with pkgs; let
    format = pkgs.formats.toml { };
  in
  (
    format.generate "config" {
      build.rustc-wrapper = "${sccache}/bin/sccache";
      target.x86_64-apple-darwin.rustflags = [ "-C" "link-arg=-fuse-ld=${zld}/bin/zld" ];
      target.aarch64-apple-darwin.rustflags = [ "-C" "link-arg=-fuse-ld=${zld}/bin/zld" ];
    }
  );

  home.file.".phoenix.js".source = ./phoenix.js;

  programs = {
    aria2.enable = true;
    bat = {
      enable = true;
      config = {
        theme = "TwoDark";
      };
    };
    lsd.enable = true;
    htop.enable = true;
    lf = with pkgs;
      let
        cleaner = writeShellScript "cleaner" "kitty +icat --clear --silent --transfer-mode file";
      in
      {
        enable = true;
        previewer.source = lib.getExe pistol;
        settings = {
          hidden = true;
          incsearch = true;
          smartcase = true;
        };
        extraConfig = ''
          set cleaner ${cleaner}
        '';
      };
    pistol = {
      enable = true;
      config = with pkgs; let
        vidthumb = writeShellApplication {
          name = "vidthumb";
          # ffmpegthumbnailer is not available on darwin, use homebrew to manage instead.
          runtimeInputs = [ jq ];
          text = builtins.readFile ./kitty/vidthumb.sh;
        };
        batViewer = "${lib.getExe bat} --style=plain --paging=never --color=always %pistol-filename%";
        kittyViewer = x:
          "sh: kitty +icat --silent --transfer-mode file --place %pistol-extra0%x%pistol-extra1%@%pistol-extra2%x%pistol-extra3% "
          + x "%pistol-filename% && exit 1";
        imageViewer = kittyViewer (x: x);
        videoViewer = kittyViewer (x: "$(${lib.getExe vidthumb} %pistol-filename%)");
      in
      {
        "text/*" = batViewer;
        "application/json" = batViewer;
        "image/*" = imageViewer;
        "video/*" = videoViewer;
      };
    };
    kitty = {
      enable = true;
      theme = "One Half Dark";
      keybindings =
        let tabKeyBindings = with builtins; listToAttrs (builtins.map
          (idx: {
            name = "cmd+${toString idx}";
            value = "goto_tab ${toString idx}";
          })
          (genList (x: x + 1) 9));
        in
        pkgs.lib.mergeAttrs tabKeyBindings {
          "cmd+shift+l" = "send_text application ;z";
        };
      font = {
        package = pkgs.sarasa-gothic;
        name = "Sarasa Term SC";
        size = 16;
      };
      settings = {
        bold_font = "Sarasa Term SC Bold";
        italic_font = "Sarasa Term SC Italic";
        bold_italic_font = "Sarasa Term SC Bold Italic";
        background_opacity = "0.98";
        hide_window_decorations = "titlebar-only";
        tab_bar_edge = "top";
        tab_bar_style = "powerline";
        tab_powerline_style = "slanted";
        tab_title_template = "{fmt.fg.red}{bell_symbol}{activity_symbol}{fmt.fg.tab}{title} {index}";
      };
    };
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
        ssh = "kitty +kitten ssh";
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
            rev = "bcff8c8504ea7efd0fc8c696dfdc8762e4bfbbb6";
            sha256 = "jH1aTY7vvbA5zygdwUhOloREwjOPftXU/GGuxElTvFE=";
          };
        }
        {
          name = "completion";
          file = "init.zsh";
          src = pkgs.fetchFromGitHub {
            owner = "zimfw";
            repo = "completion";
            rev = "6a78111576cd0c653e0fbeb1ead5d2de3b490440";
            sha256 = "dFFkeQkoGpi4aJkkq4gXExcAKLN/XtwvqT6TRA09nnA=";
          };
        }
        {
          name = "git";
          file = "init.zsh";
          src = pkgs.fetchFromGitHub {
            owner = "zimfw";
            repo = "git";
            rev = "e9e5a824ec3cb032b8d9c0b2af07b81b3366444d";
            sha256 = "+jObnCjJVqCZzoCHgPyFTJJuxwrmqCiDzqFPCuqTX34=";
          };
        }
        {
          name = "utility";
          file = "init.zsh";
          src = pkgs.fetchFromGitHub {
            owner = "zimfw";
            repo = "utility";
            rev = "2696a4da0dfb901753f92c071437606c5156cc0f";
            sha256 = "GmiaToncT/C4/qoN+9ierFY54FGZejUvlomDZoi9qH8=";
          };
        }
        {
          name = "zsh-completions";
          src = pkgs.fetchFromGitHub {
            owner = "zsh-users";
            repo = "zsh-completions";
            rev = "57330ba11b1d10ba6abba35c2d79973834fb65a6";
            sha256 = "1oOuazjCcExjiPruDvnLj9J/EnAH65o/okpXRmL/k08=";
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
        autoload -U up-line-or-beginning-search
        autoload -U down-line-or-beginning-search
        zle -N up-line-or-beginning-search
        zle -N down-line-or-beginning-search
        bindkey "$terminfo[kcuu1]" up-line-or-beginning-search # Up
        bindkey "$terminfo[kcud1]" down-line-or-beginning-search # Down

        function set-title-precmd() {
          printf '\033]0;%s\007' "''${''${PWD/#$HOME/~}##*/}"
        }

        function set-title-preexec() {
          printf '\033]0;%s\007' "''${1%% *}"
        }

        autoload -Uz add-zsh-hook
        add-zsh-hook precmd set-title-precmd
        add-zsh-hook preexec set-title-preexec
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
