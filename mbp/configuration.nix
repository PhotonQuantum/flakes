{ pkgs, ... }:

{
  imports = [
    ./brew.nix
    ./aerospace/config.nix
    ./sketchybar/config.nix
  ];

  nixpkgs.config.allowUnfree = true;

  users.users.lightquantum = {
    home = "/Users/lightquantum";
    shell = pkgs.fish;
  };
  users.users.root = {
    home = "/var/root";
  };

  environment = {
    shells = [ pkgs.fish ]; # Default shell
    variables = {
      # System variables
      SHELL = "${pkgs.fish}/bin/fish";
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
      "/Library/Tex/texbin"
    ];
  };

  environment.systemPackages =
    let
      cargoPackages = with pkgs; [
        cargo-about
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
        cargo-outdated
        cargo-readme
        cargo-sort
        cargo-udeps
        cargo-update
        cargo-wipe
      ];

      gitPackages = with pkgs; [
        delta
        git-absorb
        (git-branchless.overrideAttrs (old: {
          doCheck = false;
          doInstallCheck = false;
        }))
        git-crypt
        git-filter-repo
        git-machete
      ];

      migratedPackages = with pkgs; [
        # miniserve
        # mongodb
        ncdu
        # pkg-config
        asciinema
        atool
        autoconf
        automake
        bison
        borgbackup
        calc
        ffmpeg
        flyctl
        frp
        gawk
        go
        graphviz
        hugo
        hyperfine
        imagemagick
        just
        mdbook
        mongosh
        mtr
        navi
        neofetch
        ngrok
        ninja
        nodejs
        ocamlPackages.zarith
        opencv
        openjdk
        openssl_3
        p7zip
        pandoc
        topgrade
        wget
        yarn
        yasm
        (python3.withPackages (
          p: with p; [
            ipython
            pip
            pygments
          ]
        ))
      ];
      wasmPackages = with pkgs; [
        binaryen
        twiggy
        wasmtime
      ];
      nixPackages = with pkgs; [
        # rnix-lsp
        cachix
        colmena
        nh
        nixd
        nil
        nix-output-monitor
        nix-tree
        nixfmt-rfc-style
        nixpkgs-fmt
      ];
    in
    with pkgs;
    [
      # ghc   # maybe we should manage haskell stuff by ghcup?
      haskell-language-server
      bun
      bunyan-rs
      diesel-cli
      dotnet-sdk
      dua
      element-desktop
      fd
      gmp
      gnupg
      gpg-tui
      lazydocker
      nasm
      pinentry_mac
      ripgrep
      sbt
      scala
      smartmontools
      tex-fmt
      typos
      typst
      typstyle
      universal-ctags
      vimv
      xcaddy
      yubikey-manager
      minisat
    ]
    ++ cargoPackages
    ++ gitPackages
    ++ migratedPackages
    ++ wasmPackages
    ++ nixPackages;

  fonts = {
    packages = with pkgs; [
      jetbrains-mono
      sarasa-gothic
      ibm-plex
    ];
  };

  security.pam.enableSudoTouchIdAuth = true;

  nix.package = pkgs.nix;
  nix.gc.automatic = true;
  nix.settings = {
    trusted-users = [ "lightquantum" ]; # Allow me to interact with the daemon without sudo
    download-buffer-size = 134217728;
    experimental-features = [
      "nix-command"
      "flakes"
    ]; # Enable flakes support
  };
  nix.buildMachines = [
    {
      hostName = "meow";
      system = "x86_64-linux";
      maxJobs = 1;
      supportedFeatures = [
        "benchmark"
        "big-parallel"
        "kvm"
        "nixos-test"
      ];
    }
  ];
  nix.distributedBuilds = true;
  nixpkgs.config.permittedInsecurePackages = [
    "openssl-1.1.1u"
  ];

  programs.zsh.enable = true;
  programs.fish.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  services.nix-daemon.enable = true;

  system.stateVersion = 5;
}
