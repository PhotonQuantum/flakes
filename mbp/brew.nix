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
  ];
  homebrew.brews = [
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
    "textidote"
    "ffmpegthumbnailer"
    "messense/macos-cross-toolchains/x86_64-unknown-linux-musl"
    "mongodb-database-tools"
    {
      name = "rabbitmq";
      restart_service = "changed";
    }
    {
      name = "mongodb-community";
      restart_service = "changed";
    }
    {
      name = "redis";
      restart_service = "changed";
    }
    {
      name = "mysql";
      restart_service = "changed";
    }
    {
      name = "postgresql";
      restart_service = "changed";
    }
    "pg_cron"
  ];
  homebrew.casks = [
    "1password"
    "1password-cli"
    "adobe-acrobat-reader"
    "apache-directory-studio"
    "apparency"
    "backuploupe"
    "bartender"
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
    "lark"
    "macfuse"
    "mactex"
    "malus"
    "mattermost"
    "mongodb-compass"
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
