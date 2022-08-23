{ system, config, home-manager, pkgs, ... }:

{
  users.users.lightquantum = {
    home = "/Users/lightquantum";
    shell = [ pkgs.zsh ];
  };

  environment = {
    shells = [ pkgs.zsh ];          # Default shell
    variables = {                         # System variables
      EDITOR = "nvim";
      VISUAL = "nvim";
    };
  };

  environment.systemPackages = with pkgs; [
    rnix-lsp
  ];

  security.pam.enableSudoTouchIdAuth = true;

  nix.package = pkgs.nix;
  nix.settings = {
    trusted-users = [ "lightquantum" ];			# Allow me to interact with the daemon without sudo
    experimental-features = [ "nix-command" "flakes" ];	# Enable flakes support
  };

  programs.zsh.enable = true;

  services = {
    nix-daemon.enable = true;
  };
}
