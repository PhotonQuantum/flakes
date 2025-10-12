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
    ../common/bat.nix
    ../common/gh.nix
    ../common/ghostty.nix
    ../common/lazygit.nix
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
    lsd.enable = true;
    htop.enable = true;
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
    gh = {
      enable = true;
      settings = {
        aliases = {
          "transfer" = "api repos/$1/transfer -f new_owner=$2";
        };
      };
    };
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
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    home-manager.enable = true;
    fish = {
      shellAbbrs = {
        claude = "/Users/lightquantum/.claude/local/claude";
      };
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
    skim.enable = true;
    # opam.enable = true;
    git = {
      # Extra configuration on top of the common git module
      signing = {
        # key = "A99DCF320110092028ECAC42E53ED56B7F20B7BB";
        # signByDefault = false;
      };
    };
  };
}
