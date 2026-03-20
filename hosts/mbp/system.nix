{ pkgs, lib, lqPkgs, ... }:

{
  imports = [
    ./brew.nix
    ./aerospace/config.nix
    ./sketchybar/config.nix
    ../../profiles/system/capabilities/minimal.nix
  ];

  system.primaryUser = "lightquantum";

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
      SHELL = lib.getExe pkgs.fish;
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
        git-branchless
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
        gawk
        go
        graphviz
        hyperfine
        imagemagick
        just
        mdbook
        ngrok
        ninja
        nodejs
        openjdk
        openssl_3
        p7zip
        pandoc
        wget
        yarn
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
        cachix
        colmena
        lqPkgs.denix
        devenv
        nh
        nixd
        nil
        nix-tree
        nixfmt
        nixpkgs-fmt
        lqPkgs."validate-cam-imports"
      ];
    in
    with pkgs;
    [
      diesel-cli
      dotnet-sdk
      dua
      fd
      gmp
      gnupg
      gpg-tui
      lazydocker
      pinentry_mac
      ripgrep
      smartmontools
      tex-fmt
      typst
      typstyle
      universal-ctags
      xcaddy
      yubikey-manager
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

  security.pam.services.sudo_local.touchIdAuth = true;

  nix.enable = false;

  determinateNix = {
    enable = true;
    distributedBuilds = true;
    buildMachines = [
      {
        hostName = "lightquantum-homelab.local";
        sshUser = "lightquantum";
        system = "x86_64-linux";
        maxJobs = 16;
        supportedFeatures = [
          "benchmark"
          "big-parallel"
          "kvm"
          "nixos-test"
        ];
      }
    ];
    customSettings = {
      trusted-users = [ "lightquantum" ]; # Allow me to interact with the daemon without sudo
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };
    determinateNixd.garbageCollector.strategy = "automatic";
  };
  nixpkgs.config = {
    permittedInsecurePackages = [
      "openssl-1.1.1u"
    ];
    allowUnfree = true;
    allowUnfreePredicate = _: true;
  };
  ids.gids.nixbld = 30000;  # NOTE this only works for current installation

  programs.zsh.enable = true;
  programs.fish.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  system.stateVersion = 5;
}
