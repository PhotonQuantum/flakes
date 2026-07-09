_: {
  homebrew.enable = true;
  homebrew.global.autoUpdate = true;
  homebrew.onActivation = {
    autoUpdate = true;
    upgrade = true;
    cleanup = "uninstall";
  };
  homebrew.taps = [
    {
      name = "borgbackup/tap";
      trusted = true;
    }
    "homebrew/cask"
    "homebrew/services"
    {
      name = "sikarugir-app/sikarugir";
      trusted = true;
    }
    {
      name = "messense/macos-cross-toolchains";
      trusted = true;
    }
    {
      name = "minio/stable";
      trusted = true;
    }
    {
      name = "mongodb/brew";
      trusted = true;
    }
    {
      name = "photonquantum/tap";
      trusted = true;
    }
  ];
  homebrew.brews = [
    "act"
    "agda"
    "autoconf"
    "borgbackup-fuse"
    "cmake"
    "dlib"
    "ffmpegthumbnailer"
    "ghcup"
    "jdupes"
    "libpng"
    "mcp-proxy"
    "messense/macos-cross-toolchains/x86_64-unknown-linux-musl"
    "miniserve"
    "opam"
    "pdm"
    "pg_cron"
    "pipenv"
    "pipx"
    "pnpm"
    "poppler"
    "sqlx-cli"
    "terminal-notifier"
    "textidote"
    "tmexclude"
    "uv"
  ];
  homebrew.casks = [
    "1password-cli"
    "1password"
    "adguard"
    "adobe-acrobat-reader"
    "apache-directory-studio"
    "background-music"
    "backuploupe"
    "baidunetdisk"
    "chatgpt"
    "cheatsheet"
    "clashx-pro"
    "codex-app"
    "deepl"
    "discord"
    "dropbox"
    "element"
    "font-iosevka-nerd-font"
    "font-libertinus"
    # "ghostty"
    "github"
    "grammarly-desktop"
    "handbrake-app"
    "iina"
    "jetbrains-toolbox"
    "karabiner-elements"
    "sikarugir-app/sikarugir/sikarugir"
    "keka"
    "kekaexternalhelper"
    "keyboard-lock"
    "keycastr"
    "latest"
    "macfuse"
    "macgpt"
    "mactex"
    "malus"
    "mathpix-snipping-tool"
    "monitorcontrol"
    "nightowl"
    "notion"
    "obs"
    "openinterminal"
    "orbstack"
    "phoenix"
    "postman"
    "prusaslicer"
    "qlmarkdown"
    "qq"
    "raycast"
    "setapp"
    "slidepilot"
    "squirrel-app"
    "stats"
    "steam"
    "syncplay"
    "syncthing-app"
    "syntax-highlight"
    "tailscale-app"
    "tencent-meeting"
    "tg-pro"
    "thaw"
    "tunnelblick"
    "typora"
    "ultimaker-cura"
    "visual-studio-code"
    "vivaldi"
    "vlc"
    "vorta"
    "zoom"
    "zotero"
    "zulip"
    # "bartender" // managed by setapp
  ];
}
