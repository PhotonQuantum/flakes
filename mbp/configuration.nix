{ system, config, nixpkgs, home-manager, pkgs, ... }:

{
  imports = [
    ./brew.nix
  ];

  nixpkgs.config.allowUnfree = true;

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
      HOMEBREW_PREFIX = "/opt/homebrew";
      HOMEBREW_CELLAR = "/opt/homebrew/Cellar";
      HOMEBREW_REPOSITORY = "/opt/homebrew";
      HOMEBREW_SHELLENV_PREFIX = "/opt/homebrew";
    };
    systemPath = [
      "/opt/homebrew/bin"
      "/opt/homebrew/sbin"
    ];
  };

  environment.systemPackages =
    let
      cargoPackages = with pkgs; [
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
        cargo-readme
        cargo-sort
        cargo-udeps
        cargo-update
        cargo-wipe
        cargo-outdated
      ];

      gitPackages = with pkgs; [
        git-machete
        git-crypt
        git-absorb
        git-branchless
        delta
      ];

      migratedPackages = with pkgs; [
        asciinema
        pkgconfig
        atool
        autoconf
        automake
        bison
        bitwarden-cli
        borgbackup
        calc
        cmake
        ffmpeg
        frp
        gawk
        go
        graphviz
        unstable.hugo
        hyperfine
        imagemagick
        python310
        python310Packages.ipython
        python310Packages.pip
        jmeter
        unstable.mongosh
        tesseract
        just
        mdbook
        minisat
        # miniserve
        mosh
        mtr
        navi
        ncdu
        ninja
        nodejs
        nodejs-16_x
        neofetch
        # mongodb
        nodejs-14_x
        ocamlPackages.zarith
        opencv
        openjdk
        openssl_3
        p7zip
        pandoc
        flyctl
        swiProlog
        unstable.topgrade
        wget
        yarn
        yasm
        unstable.zig
        ngrok
      ];
      guiPackages = with pkgs; [
        iterm2
      ];
      fontPackages = with pkgs; [
        jetbrains-mono
        sarasa-gothic
      ];
    in
    with pkgs; [
      rnix-lsp
      colmena
      bunyan-rs
      lazydocker
      unstable.diesel-cli
      typos
      cachix
      bacon
      dua
      fd
      smartmontools
      gnupg
      pinentry_mac
    ] ++ cargoPackages ++ gitPackages ++ migratedPackages ++ guiPackages ++ fontPackages;

  security.pam.enableSudoTouchIdAuth = true;

  nix.package = pkgs.nix;
  nix.gc.automatic = true;
  nix.settings = {
    trusted-users = [ "lightquantum" ]; # Allow me to interact with the daemon without sudo
    experimental-features = [ "nix-command" "flakes" ]; # Enable flakes support
    auto-optimise-store = true;
  };

  programs.zsh.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  services = {
    nix-daemon.enable = true;
  };
}
