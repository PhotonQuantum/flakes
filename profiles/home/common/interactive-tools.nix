{
  programs = {
    lsd.enable = true;
    htop.enable = true;

    gh = {
      enable = true;
      settings.aliases = {
        transfer = "api repos/$1/transfer -f new_owner=$2";
      };
    };

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    home-manager.enable = true;
  };
}
