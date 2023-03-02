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
  ];
  homebrew.casks = [
    "1password"
    "1password-cli"
    "apache-directory-studio"
    "apparency"
    "backuploupe"
    "baidunetdisk"
    "bartender"
    "caffeine"
    "charles"
    "cheatsheet"
    "clashx-pro"
    "deepl"
    "discord"
    "docker"
    "dropbox"
    "feishu"
    "figma"
    "font-iosevka-nerd-font"
    "gimp"
    "github"
    "iina"
    "jetbrains-toolbox"
    "keka"
    "kekaexternalhelper"
    "keyboard-lock"
    "lark"
    "macfuse"
    "mactex"
    "mongodb-compass"
    "nightowl"
    "notion"
    "obs"
    "openinterminal"
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
    "yubico-yubikey-manager"
    "zoom"
  ];
}
