_:
{
  homebrew.enable = true;
  homebrew.global.autoUpdate = false;
  homebrew.onActivation = {
    autoUpdate = true;
    upgrade = true;
    cleanup = "uninstall";
  };
  homebrew.taps = [
    "homebrew/cask"
    "homebrew/cask-fonts"
    "homebrew/cask-drivers"
    "mongodb/brew"
    "photonquantum/tap"
    "homebrew/cask-versions"
  ];
  homebrew.brews = [
    "miniserve"
    "pipenv"
    "pipx"
    "pnpm"
    "mongodb-database-tools"
    {
      name = "tmexclude";
      restart_service = "changed";
    }
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
    "charles"
    "cheatsheet"
    "clashx-pro"
    "deepl"
    "docker"
    "dropbox"
    "figma"
    "font-iosevka-nerd-font"
    "gimp"
    "github"
    "gitkraken"
    "handbrake"
    "iina"
    "jetbrains-toolbox"
    "keka"
    "kekaexternalhelper"
    "keyboard-lock"
    "mactex"
    "mongodb-compass"
    "nightowl"
    "notion"
    "obs"
    "openinterminal"
    "paw"
    "postman"
    "qbittorrent"
    "qlmarkdown"
    "raycast"
    "rectangle"
    "setapp"
    "shottr"
    "squirrel"
    "steam"
    "syntax-highlight"
    "tencent-meeting"
    "tg-pro"
    "thunder"
    "typora"
    "visual-studio-code"
    "vlc"
    "vorta"
    "warp"
    "yubico-yubikey-manager"
    "zoom"
    "iterm2"
  ];
}