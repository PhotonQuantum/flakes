{
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ../../profiles/home/capabilities/minimal.nix
    ../../profiles/home/capabilities/interactive.nix
    ../../profiles/home/capabilities/graphics.nix
    ../../profiles/home/capabilities/development.nix
    ../../secrets/ssh.nix
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
      ../../wallpaper/celeste.png
      ../../wallpaper/celeste.png
      # ../../wallpaper/exodus.heic
      # ../../wallpaper/landscape.heic
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
    git = {
      # Extra configuration on top of the common git module
      signing = {
        # key = "A99DCF320110092028ECAC42E53ED56B7F20B7BB";
        # signByDefault = false;
      };
    };
  };
}
