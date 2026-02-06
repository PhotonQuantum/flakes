_:

{
  imports = [
    ../../profiles/home/capabilities/minimal.nix
    ../../profiles/home/capabilities/interactive.nix
    ../../profiles/home/capabilities/development.nix
  ];

  home = {
    username = "lightquantum";
    homeDirectory = "/home/lightquantum";
    stateVersion = "22.05";
  };

  programs = {
    home-manager.enable = true;
    zsh = {
      enable = true;
      shellAliases = {
        vim = "nvim";
      };
      syntaxHighlighting = {
        enable = true;
      };
      oh-my-zsh = {
        enable = true;
      };
    };
    starship.enable = true;
    lazygit.enable = true;
  };
}
