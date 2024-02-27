_:
{
  homebrew.enable = true;
  homebrew.global.autoUpdate = true;
  homebrew.onActivation = {
    autoUpdate = true;
    upgrade = true;
    cleanup = "uninstall";
  };
  homebrew.taps = [
    "homebrew/cask"
    "homebrew/cask-fonts"
    "homebrew/cask-drivers"
    "homebrew/services"
    "mongodb/brew"
    "photonquantum/tap"
    "homebrew/cask-versions"
    "messense/macos-cross-toolchains"
    "minio/stable"
    "borgbackup/tap"
  ];
  homebrew.brews = [
    "autoconf"
    "borgbackup-fuse"
    "cmake"
    "dlib"
    "libpng"
    "minio"
    "miniserve"
    "pipenv"
    "pipx"
    "pdm"
    "pnpm"
    "sqlx-cli"
    "terminal-notifier"
    "textidote"
    "ffmpegthumbnailer"
    "messense/macos-cross-toolchains/x86_64-unknown-linux-musl"
    "mongodb-database-tools"
    {
      name = "rabbitmq";
      # restart_service = "changed";
    }
    {
      name = "mongodb-community";
      # restart_service = "changed";
    }
    {
      name = "redis";
      # restart_service = "changed";
    }
    {
      name = "mysql";
      # restart_service = "changed";
    }
    {
      name = "postgresql";
      # restart_service = "changed";
    }
    "pg_cron"
  ];
  homebrew.casks = [
    "1password"
    "1password-cli"
    "adguard"
    "adobe-acrobat-reader"
    "anydesk"
    "apache-directory-studio"
    "apparency"
    "backuploupe"
    # "bartender" // managed by setapp
    "charles"
    "cheatsheet"
    "clashx-pro"
    "deepl"
    "discord"
    "dropbox"
    "feishu"
    "figma"
    "font-iosevka-nerd-font"
    "gimp"
    "github"
    "grammarly-desktop"
    "handbrake"
    "iina"
    "jetbrains-toolbox"
    "keka"
    "kekaexternalhelper"
    "keyboard-lock"
    "keycastr"
    "lark"
    "latest"
    "macfuse"
    "macgpt"
    "mactex"
    "malus"
    "mathpix-snipping-tool"
    "mattermost"
    "mongodb-compass"
    "monitorcontrol"
    "nightowl"
    "notion"
    "obs"
    "openinterminal"
    "orbstack"
    "paw"
    "phoenix"
    "postman"
    "qbittorrent"
    "qlmarkdown"
    "qq"
    "raycast"
    "rectangle"
    "redisinsight"
    "setapp"
    "shottr"
    "slidepilot"
    "squirrel"
    "steam"
    "syntax-highlight"
    "tencent-meeting"
    "voov-meeting"
    "tg-pro"
    "thunder"
    "typora"
    "visual-studio-code"
    "vlc"
    "vorta"
    "warp"
    "zoom"
    "zotero"
  ];
}
