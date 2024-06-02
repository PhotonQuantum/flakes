{ pkgs, lib, system, osConfig, yazi, ... }:

let
  recursiveMerge = with lib; attrList:
    let
      f = attrPath:
        zipAttrsWith (n: values:
          if tail values == [ ]
          then head values
          else if all isList values
          then unique (concatLists values)
          else if all isAttrs values
          then f (attrPath ++ [ n ]) values
          else last values
        );
    in
    f [ ] attrList;
  compose = with pkgs.lib; l: flip pipe (reverseList l);
in
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
      PNPM_HOME = "$HOME/Library/pnpm";
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
    defaultShell = pkgs.fish;
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
  home.file."Library/Application Support/Google/Chrome/NativeMessagingHosts/gpgmejson.json".source =
    let
      format = pkgs.formats.json { };
    in
    (
      format.generate "config" {
        name = "gpgmejson";
        description = "JavaScript binding for GnuPG";
        path = "${pkgs.gpgme.dev}/bin/gpgme-json";
        type = "stdio";
        allowed_origins = [
          "chrome-extension://kajibbejlbohfaggdiogboambcijhkke/"
        ];
      }
    );


  programs = {
    ssh.enable = true;
    aria2.enable = true;
    bat = {
      enable = true;
      config = {
        theme = "base16";
      };
    };
    lsd = {
      enable = true;
      enableAliases = true;
    };
    htop.enable = true;
    lf = with pkgs;
      {
        enable = true;
        previewer.source = lib.getExe' pistol "pistol";
        settings = {
          hidden = true;
          incsearch = true;
          smartcase = true;
        };
      };
    yazi = {
      enable = true;
      enableFishIntegration = true;
      package = yazi.packages.${system}.yazi;
      keymap =
        let
          preset = builtins.fromTOML (builtins.readFile ./yazi/keymap_preset.toml);
          user = {
            manager.keymap =
              [
                { on = [ "<C-c>" ]; exec = "escape"; desc = "Exit visual mode, clear selected, or cancel search"; }
              ];
            input.keymap = [
              { on = [ "<C-c>" ]; exec = "close"; desc = "Cancel input"; }
              { on = [ "<S-Enter>" ]; exec = "escape"; desc = "Go back the normal mode, or cancel input"; }
              { on = [ "H" ]; exec = "move -999"; desc = "Move to the BOL"; }
              { on = [ "L" ]; exec = "move 999"; desc = "Move to the EOL"; }
            ];
          };
        in
        recursiveMerge [ preset user ];
      settings = {
        manager = {
          layout = [ 1 3 4 ];
        };
        opener.archive = [
          { exec = "aunpack \"$1\""; desc = "Extract here"; }
        ];
      };
      theme = {
        manager = {
          syntect_theme = ./yazi/TwoDark.tmTheme;
        };
      };
    };
    pistol = {
      enable = true;
      associations = with pkgs; let
        batViewer = "${lib.getExe bat} --style=plain --paging=never --color=always %pistol-filename%";
      in
      [
        { mime = "text/*"; command = batViewer; }
        { mime = "application/json"; command = batViewer; }
      ];
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
        
        return config
      '';
    };
    kitty = {
      # enable = true;
      package = pkgs.kitty.overrideAttrs
        (old: {
          doCheck = false;
          doInstallCheck = false;
        });
      keybindings =
        let
          tabKeyBindings = with builtins; listToAttrs (builtins.map
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
        disable = [ "brew_cask" "brew_formula" "mas" "nix" "shell" "node" ];
      };
    };
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    home-manager.enable = true;
    fish = {
      enable = true;
      shellAliases = {
        vim = "nvim";
        coqtags = "fd -e v . . ~/.opam/default/lib/coq/theories -X ctags --options=/Users/lightquantum/.config/coq.ctags";
        # ssh = "kitty +kitten ssh";
        lf = "lfcd";
      };
      shellAbbrs = import ./fish/git_abbr.nix;
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
        lfcd = ''
          set tmp (mktemp)
          # `command` is needed in case `lfcd` is aliased to `lf`
          command lf -last-dir-path=$tmp $argv
          if test -f "$tmp"
              set dir (cat $tmp)
              rm -f $tmp
              if test -d "$dir"
                  if test "$dir" != (pwd)
                      cd $dir
                  end
              end
          end
        '';
        fish_greeting = "";
        fish_right_prompt = "";
        fish_prompt_loading_indicator = {
          argumentNames = "last_prompt";
          body = ''
            echo -n "$last_prompt" | head -n2 | tail -n1 | read -zl last_prompt_line
            echo -n "$last_prompt_line" | cut -d, -f1-2 | read -l last_prompt_directory

            starship module directory | read -zl current_prompt_directory

            echo
            if [ "$last_prompt_directory" = "$current_prompt_directory" ]
                echo "$last_prompt" | tail -n2
            else
                echo "$current_prompt_directory"
                starship module character
            end
          '';
        };
      };
      shellInit = ''
        set -x MANPATH "/opt/homebrew/share/man" $MANPATH
        set -x INFOPATH "/opt/homebrew/share/info" $INFOPATH
        fish_add_path --prepend --global ~/.cargo/bin
        fish_add_path --prepend --global ~/.nargo/bin
        set fish_escape_delay_ms 300
        builtin functions -e fish_mode_prompt
        eval (${pkgs.starship}/bin/starship init fish)
      '' + builtins.readFile ./wezterm.fish;
      loginShellInit =
        let
          # This naive quoting is good enough in this case. There shouldn't be any
          # double quotes in the input string, and it needs to be double quoted in case
          # it contains a space (which is unlikely!)
          dquote = str: "\"" + str + "\"";

          makeBinPathList = map (path: path + "/bin");
        in
        ''
          fish_add_path --move --prepend --path ${lib.concatMapStringsSep " " dquote (makeBinPathList osConfig.environment.profiles)}
          set fish_user_paths $fish_user_paths
        '';
      plugins = [
        {
          name = "Done";
          inherit (pkgs.generated.fish_done) src;
        }
        {
          name = "sponge";
          inherit (pkgs.generated.fish_sponge) src;
        }
        {
          name = "autopairs";
          inherit (pkgs.generated.fish_autopairs) src;
        }
        {
          name = "puffer_fish";
          inherit (pkgs.generated.fish_puffer_fish) src;
        }
        {
          name = "async_prompt";
          inherit (pkgs.generated.fish_async_prompt) src;
        }
        {
          name = "abbreviation_tips";
          inherit (pkgs.generated.fish_abbreviation_tips) src;
        }
        {
          name = "jump";
          inherit (pkgs.generated.fish_jump) src;
        }
        {
          name = "sudope";
          inherit (pkgs.generated.fish_sudope) src;
        }
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
    starship = {
      enable = true;
      enableFishIntegration = false; # Fish integration is handled by `fish` module
      settings =
        let
          presets = with builtins;
            map (compose [ fromTOML readFile (s: ./starship + "/${s}") ])
              (compose [ attrNames (lib.filterAttrs (_: kind: kind == "regular")) readDir ]
                (./starship));
        in
        {
          git_status = {
            ahead = "↑\${count}";
            behind = "↓\${count}";
            conflicted = "✖";
            diverged = "⇅↑\${ahead_count}↓\${behind_count}";
            modified = "※";
            staged = "✓";
            stashed = "";
            untracked = "";
            ignore_submodules = true;
          };
          ocaml.detect_files = [ "dune" "dune-project" "jbuild" "jbuild-ignore" ".merlin" "_CoqProject" ];
          character = {
            success_symbol = "[⊢](bold green) ";
            error_symbol = "[⊢](bold red) ";
          };
        } // recursiveMerge presets;
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
