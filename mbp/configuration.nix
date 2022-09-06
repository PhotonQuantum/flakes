{ system, config, home-manager, pkgs, ... }:

{
  users.users.lightquantum = {
    home = "/Users/lightquantum";
    shell = [ pkgs.zsh ];
  };

  environment = {
    shells = [ pkgs.zsh ]; # Default shell
    variables = {
      # System variables
      EDITOR = "nvim";
      VISUAL = "nvim";
    };
  };

  environment.systemPackages = with pkgs; [
    rnix-lsp
    colmena
    git-machete
    bunyan-rs
    lazydocker
    diesel-cli
    typos
    git-crypt
    cachix
    bacon
    cargo-audit
    cargo-bloat
    cargo-cache
    cargo-expand
    cargo-fuzz
    cargo-generate
    cargo-insta
    cargo-modules
    cargo-msrv
    cargo-nextest
    cargo-sort
    cargo-udeps
    cargo-update
    cargo-wipe
    skim
    lf
    dua
  ];

  security.pam.enableSudoTouchIdAuth = true;

  nix.package = pkgs.nix;
  nix.gc.automatic = true;
  nix.settings = {
    trusted-users = [ "lightquantum" ]; # Allow me to interact with the daemon without sudo
    experimental-features = [ "nix-command" "flakes" ]; # Enable flakes support
    auto-optimise-store = true;
  };

  programs.zsh.enable = true;

  services = {
    nix-daemon.enable = true;
  };
}
