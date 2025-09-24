{
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ../common/vim.nix
    ../common/starship.nix
    ../common/yazi.nix
    ../common/fish.nix
    ../common/git.nix
    ../secrets/ssh.nix
    ./aerospace/home.nix
    ./sketchybar/home.nix
  ];

  home = {
    username = "lightquantum";
    homeDirectory = "/Users/lightquantum";
    stateVersion = "22.05";
    sessionVariables = {
      PNPM_HOME = "$HOME/Library/pnpm";
    };
    sessionPath = [
      "$HOME/.local/bin"
      "$HOME/opt/GNAT/2020/bin"
      "$HOME/Library/pnpm"
    ];
    wallpapers = [
      ../wallpaper/celeste.png
      ../wallpaper/celeste.png
      # ../wallpaper/exodus.heic
      # ../wallpaper/landscape.heic
    ];
    defaultShell = pkgs.fish;
    shell.enableShellIntegration = true;
    disableMacPowerButton = true;
  };

  home.Xcompose = import ./Xcompose.nix;

  home.file.".cargo/config.toml".source =
    with pkgs;
    let
      format = pkgs.formats.toml { };
    in
    (format.generate "config" {
      build.rustc-wrapper = lib.getExe sccache;
      target.x86_64-apple-darwin.rustflags = [
        "-C"
        "link-arg=-fuse-ld=${lib.getExe' zld "zld"}"
      ];
      target.aarch64-apple-darwin.rustflags = [
        "-C"
        "link-arg=-fuse-ld=${lib.getExe' zld "zld"}"
      ];
    });

  home.file.".phoenix.js".source = ./phoenix.js;
  home.file."Library/Application Support/Google/Chrome/NativeMessagingHosts/gpgmejson.json".source =
    let
      format = pkgs.formats.json { };
    in
    (format.generate "config" {
      name = "gpgmejson";
      description = "JavaScript binding for GnuPG";
      path = lib.getExe' pkgs.gpgme.dev "gpgme-json";
      type = "stdio";
      allowed_origins = [
        "chrome-extension://kajibbejlbohfaggdiogboambcijhkke/"
      ];
    });

  programs = {
    ssh = {
      enable = true;
      includes = [ "~/.orbstack/ssh/config" ];
    };
    aria2.enable = true;
    bat = {
      enable = true;
      config = {
        theme = "base16";
      };
    };
    lsd.enable = true;
    htop.enable = true;
    lf = with pkgs; {
      enable = false;
      previewer.source = lib.getExe' pistol "pistol";
      settings = {
        hidden = true;
        incsearch = true;
        smartcase = true;
      };
    };
    wezterm = {
      enable = true;
      extraConfig = ''
        local wezterm = require 'wezterm'
        local act = wezterm.action
        local config = {}

        config.font = wezterm.font "Sarasa Term SC"
        config.font_size = 16.0

        config.window_background_opacity = 0.8
        config.macos_window_background_blur = 80

        function get_appearance()
          if wezterm.gui then
            return wezterm.gui.get_appearance()
          end
          return 'Dark'
        end
        function scheme_for_appearance(appearance)
          if appearance:find 'Dark' then
            return 'OneDark (base16)'
          else
            return 'One Light (base16)'
          end
        end
        config.color_scheme = scheme_for_appearance(get_appearance())

        config.window_decorations = "RESIZE"
        config.hide_tab_bar_if_only_one_tab = true
        config.window_frame = {
          font = wezterm.font { family = 'Sarasa Term SC', weight = 'Bold' },
          font_size = 14.0,
        }

        config.keys = {
          {
            key = "p",
            mods = "CMD|SHIFT",
            action = wezterm.action.ActivateCommandPalette
          },
          {
            key = 'UpArrow',
            mods = 'SHIFT',
            action = act.ScrollToPrompt(-1)
          },
          {
            key = 'DownArrow',
            mods = 'SHIFT',
            action = act.ScrollToPrompt(1)
          },
        }
        for i = 1, 9 do
          table.insert(config.keys, {
            key = tostring(i),
            mods = 'CMD',
            action = act.ActivateTab(i - 1),
          })
        end

        config.mouse_bindings = {
          {
            event = { Down = { streak = 4, button = 'Left' } },
            action = wezterm.action.SelectTextAtMouseCursor 'SemanticZone',
            mods = 'NONE',
          },
        }

        config.enable_kitty_keyboard = true

        config.front_end = "WebGpu"

        return config
      '';
    };
    kitty = {
      # enable = true;
      package = pkgs.kitty.overrideAttrs (old: {
        doCheck = false;
        doInstallCheck = false;
      });
      keybindings =
        let
          tabKeyBindings =
            with builtins;
            listToAttrs (
              builtins.map (idx: {
                name = "cmd+${toString idx}";
                value = "goto_tab ${toString idx}";
              }) (genList (x: x + 1) 9)
            );
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
    gh = {
      enable = true;
      settings = {
        aliases = {
          "transfer" = "api repos/$1/transfer -f new_owner=$2";
        };
      };
    };
    skim.enable = true;
    # opam.enable = true;
    nix-index = {
      enable = true;
      enableFishIntegration = false;
    };
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
        disable = [
          "brew_cask"
          "brew_formula"
          "mas"
          "nix"
          "shell"
          "node"
        ];
      };
    };
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    home-manager.enable = true;
    ghostty = {
      enable = true;
      package = null; # managed by homebrew
      settings = {
        font-family = "Sarasa Term SC";
        font-size = 16;
        theme = "dark:Catppuccin Mocha,light:Catppuccin Latte";
        background-opacity = 0.8;
        background-blur-radius = 80;
        keybind = "global:super+,=toggle_quick_terminal";
        # keybind = global:super+,=toggle_visibility
        quick-terminal-animation-duration = 0.1;
        shell-integration-features = true;
      };
    };
    fish = {
      # Extra configuration on top of the common fish module
      functions = {
        init_conda = ''
          if test -f /Users/lightquantum/miniconda3/bin/conda
              eval /Users/lightquantum/miniconda3/bin/conda "shell.fish" "hook" $argv | source
          end
        '';
        git_sign = ''
          set FILTER_BRANCH_SQUELCH_WARNING 1
          git filter-branch --commit-filter 'git commit-tree -S "$@";' $argv[1]..HEAD
        '';
        git_delete_bak = ''
          set ref (git show-ref | awk '/ refs.original.refs/{print$2}')
          git update-ref -d $ref
        '';
      };
      shellAliases = {
        coqtags = "fd -e v . . ~/.opam/default/lib/coq/theories -X ctags --options=/Users/lightquantum/.config/coq.ctags";
      };
      shellInit = ''
        set -x MANPATH "/opt/homebrew/share/man" $MANPATH
        set -x INFOPATH "/opt/homebrew/share/info" $INFOPATH
        fish_add_path --prepend --global ~/.cargo/bin
        fish_add_path --prepend --global ~/.nargo/bin
        fish_add_path --prepend --global ~/.ghcup/bin
        fish_add_path --prepend --global ~/.elan/bin
      '';
      plugins = [
        {
          name = "brew";
          inherit (pkgs.generated.fish_brew) src;
        }
      ];
    };
    zsh = {
      enable = true;
      shellAliases = {
        vim = "nvim";
        coqtags = "fd -e v . . ~/.opam/default/lib/coq/theories -X ctags --options=/Users/lightquantum/.config/coq.ctags";
        # ssh = "kitty +kitten ssh";
      };

      syntaxHighlighting = {
        enable = true;
      };
      autosuggestion.enable = true;
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
      initContent = ''
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
        function init_conda() {
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
        }
        # <<< conda initialize <<<
        zmodload zsh/zprof
      '';
      envExtra = ". $HOME/.cargo/env";
    };
    lazygit = {
      enable = true;
      settings = {
        gui.showIcons = true;
        refresher.refreshInterval = 1;
      };
    };
    git = {
      # Extra configuration on top of the common git module
      signing = {
        # key = "A99DCF320110092028ECAC42E53ED56B7F20B7BB";
        # signByDefault = false;
      };
    };
  };
}
