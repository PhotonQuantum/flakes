{ system, config, inputs, pkgs, ... }:

{
  imports = [
    ./brew.nix
  ];

  nixpkgs.config.allowUnfree = true;

  users.users.lightquantum = {
    home = "/Users/lightquantum";
    shell = [ pkgs.zsh ];
  };
  users.users.root = {
    home = "/var/root";
  };

  environment = {
    shells = [ pkgs.zsh ]; # Default shell
    variables = {
      # System variables
      SHELL = "${pkgs.zsh}/bin/zsh";
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
        pkg-config
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
        hugo
        hyperfine
        imagemagick
        (python310.withPackages (p: with p; [
          ipython
          pip
          pygments
        ]))
        jmeter
        mongosh
        tesseract
        just
        mdbook
        minisat
        # miniserve
        mosh
        mtr
        navi
        # ncdu  # TODO temporary comment out due to llvm 15
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
        topgrade
        wget
        yarn
        yasm
        ngrok
      ];
      wasmPackages = with pkgs; [
        binaryen
        twiggy
        wasmtime
      ];
    in
    with pkgs; [
      rnix-lsp
      colmena
      bunyan-rs
      lazydocker
      diesel-cli
      typos
      cachix
      bacon
      dua
      fd
      smartmontools
      gnupg
      pinentry_mac
      bun
      gmp
      ripgrep
      config.nur.repos.lightquantum.universal-ctags-pcre2
      haskell-language-server
      ghc
      git-filter-repo
      dotnet-sdk
      scala
      sbt
      yubikey-manager
      nasm
    ] ++ cargoPackages ++ gitPackages ++ migratedPackages ++ wasmPackages;

  fonts = {
    fontDir.enable = true;
    fonts = with pkgs; [
      jetbrains-mono
      sarasa-gothic
    ];
  };

  security.pam.enableSudoTouchIdAuth = true;

  nix.package = pkgs.nix;
  nix.gc.automatic = true;
  nix.settings = {
    trusted-users = [ "lightquantum" ]; # Allow me to interact with the daemon without sudo
    experimental-features = [ "nix-command" "flakes" ]; # Enable flakes support
  };
  nix.registry.nixpkgs.flake = inputs.nixpkgs;
  nix.buildMachines = [
    {
      hostName = "meow";
      system = "x86_64-linux";
      maxJobs = 1;
      supportedFeatures = ["benchmark" "big-parallel" "kvm" "nixos-test"];
    }
  ];
  nix.distributedBuilds = true;

  programs.zsh.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  services = {
    nix-daemon.enable = true;
  };
}
