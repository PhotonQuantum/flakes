{ pkgs, ... }:

{
  imports = [
    ../common/vim.nix
    ../secrets/ssh.nix
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
    wallpapers = [
      ../wallpaper/exodus.heic
      ../wallpaper/landscape.heic
    ];
    defaultShell = pkgs.zsh;
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
    ssh.enable = true;
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
        previewer.source = lib.getExe' pistol "pistol";
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
      associations = with pkgs; let
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
      [
        { mime = "text/*"; command = batViewer; }
        { mime = "application/json"; command = batViewer; }
        { mime = "image/*"; command = imageViewer; }
        { mime = "video/*"; command = videoViewer; }
      ];
    };
    kitty = {
      enable = true;
      package = pkgs.kitty.overrideAttrs
        (old: {
          doCheck = false;
          doInstallCheck = false;
        });
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

      syntaxHighlighting = {
        enable = true;
      };
      enableAutosuggestions = true;
      plugins = [
        {
          name = "input";
          file = "init.zsh";
          inherit (pkgs.generated.zimfw_input) src;
        }
        {
          name = "completion";
          file = "init.zsh";
          inherit (pkgs.generated.zimfw_completion) src;
        }
        {
          name = "git";
          file = "init.zsh";
          inherit (pkgs.generated.zimfw_git) src;
        }
        {
          name = "utility";
          file = "init.zsh";
          inherit (pkgs.generated.zimfw_utility) src;
        }
        {
          name = "zsh-completions";
          inherit (pkgs.generated.zsh_completions) src;
        }
        {
          name = "you-should-use";
          src = "${pkgs.zsh-you-should-use}/share/zsh/plugins/you-should-use";
        }
      ];
      initExtra = ''
        # export FPATH="/opt/homebrew/share/zsh/site-functions''${FPATH+:$FPATH}";
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

        # >>> conda initialize >>>
        # !! Contents within this block are managed by 'conda init' !!
        __conda_setup="$('/Users/lightquantum/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
        if [ $? -eq 0 ]; then
            eval "$__conda_setup"
        else
            if [ -f "/Users/lightquantum/miniconda3/etc/profile.d/conda.sh" ]; then
                . "/Users/lightquantum/miniconda3/etc/profile.d/conda.sh"
            else
                export PATH="/Users/lightquantum/miniconda3/bin:$PATH"
            fi
        fi
        unset __conda_setup
        # <<< conda initialize <<<
        zmodload zsh/zprof
      '';
      envExtra = ". $HOME/.cargo/env";
    };
    starship = {
      enable = true;
      settings = {
        git_status.disabled = true;
        ocaml.detect_files = [ "dune" "dune-project" "jbuild" "jbuild-ignore" ".merlin" "_CoqProject" ];
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
      difftastic = {
        enable = true;
        display = "inline";
      };
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
        init.defaultBranch = "master";
        push.autoSetupRemote = true;
        absorb.maxStack = 50;
        merge.tool = "nvimdiff";
        core.autocrlf = "input";
      };
    };
  };
}
