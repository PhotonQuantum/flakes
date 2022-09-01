# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, home-manager, ... }:

{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  deployment.keys = {
    "homeserver.yaml" = {
      keyFile = ../secrets/homeserver.yaml;
      destDir = "/var/keys";
      user = "matrix-synapse";
      group = "matrix-synapse";
    };
    "homeserver.signing.key" = {
      keyFile = ../secrets/lightquantum.me.signing.key;
      destDir = "/var/lib/matrix-synapse";
      user = "matrix-synapse";
      group = "matrix-synapse";
    };
  };

  nix.package = pkgs.nix;
  nix.gc.automatic = true;
  nix.settings = {
    trusted-users = [ "lightquantum" ];
    experimental-features = [ "nix-command" "flakes" ];
  };

  # Use the GRUB 2 boot loader.
  boot.loader.grub = {
    enable = true;
    version = 2;
    device = "/dev/sda";
  };

  networking = {
    hostName = "lightquantum-meow"; # Define your hostname.
    interfaces.ens18.ipv4.addresses = [{
      address = "10.0.1.104";
      prefixLength = 24;
    }];
    interfaces.ens18.ipv6.addresses = [{
      address = "2a01:4f9:4a:286f:1:104::1";
      prefixLength = 80;
    }];
    defaultGateway = "10.0.1.1";
    defaultGateway6 = "2a01:4f9:4a:286f:1::1";
    nameservers = [ "1.1.1.1" "1.0.0.1" "2606:4700:4700::1111" "2606:4700:4700::1001" ];
  };

  # Set your time zone.
  time.timeZone = "asia/Shanghai";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.lightquantum = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ]; # Enable ‘sudo’ for the user.
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCu4c/RtyBgjlkM32w9qeXL/5G1xN5LbUu4M8yMXT75ZdRV5eTf9w5rgnFvf1jWmM8J97hWfqxUqCzZbPz2fB56S0r4MoA12NZduNUPbUjIJGAhf/r/aNFgVSTwep+V2OL+MZjyOi1hjklwHBpqjjz9DnSOoH+8ZhEi0U3axCC5qlKs6BI2aamiV3GMifAHXaHy8IOFWkcD+qWG6bRtfRrGpXuuB6WOUCdv1IFsiqJWnJcw2JwfgS8HAKvTZI/GuYQUJ+IbwPy7iIz7WaGXy0w9hOhTO2Bhcixf7u1uXAB86J8279IcFJ9tXhyRrE9/trX5FqIJkr/OcMUHCBS2O8uvtlhxVhegFsbo2Cg2xfbW3ri0dFm9jV0T+0JOKhLEX9trxxr2gR/uUYDyZnZ4UI6eKGKIhZOnI6B0TeKuW6ojxxgvuZJ6q4kpOSvKc7oKFM/f8w5eeqRwos6/J/K+DPIelvIMw9dPO0U/bWm8oi7d/c86q2K67MdKUpdPOVcCM0zp4KFdDl0UnLOkHMM/tgPLFwab4bmhUq57ryB5gJEW1MLA4CCQEHayGObIlzk64TZF9iUUVVPL5HsuarmDWjT3HSwyAGjp8CkfL7EVk8kWD3CiRd0VTu6qWaxTS6vbeThuGPRoyre6SPmiVWcMHJHxX+djQ305bYYsbovupVAE4Q=="
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFSZqvCJyC4hCGORRSKxWFRg8M/LK+hUebAQ8wx2xPxW lightquantum@vultr"
    ];
    home = "/home/lightquantum";
    shell = pkgs.zsh;
    createHome = true;
  };

  environment = {
    shells = [ pkgs.zsh ]; # Default shell
    variables = {
      # System variables
      EDITOR = "nvim";
      VISUAL = "nvim";
    };
  };

  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    docker-compose_2
    curl
    wget
    lazydocker
    netdata # This is necessary to bring netdata-claim.sh to default shell.
  ];

  virtualisation.docker.enable = true;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  programs.zsh.enable = true;
  programs.mtr.enable = true;
  programs.mosh.enable = true;
  programs.git = {
    enable = true;
    config = {
      pull.rebase = true;
    };
  };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    permitRootLogin = "no";
    passwordAuthentication = false;
    kbdInteractiveAuthentication = false;
    ports = [ 20422 ];
    extraConfig = ''
      ClientAliveInterval 30
      ClientAliveCountMax 2
    '';
  };

  # Enable netdata reporting.
  # Notice: don't forget to claim the server to netdata cloud.
  # ```shell
  # $ sudo netdata-claim.sh -token=<token>
  # $ sudo netdatacli reload-claiming-state
  # ```
  services.netdata = {
    enable = true;
    config = {
      ml.enabled = true;
    };
  };

  services.qemuGuest.enable = true;

  services.borgbackup.repos = {
    aliyun = {
      path = "/var/lib/borgbackup/aliyun";
      quota = "10G";
      user = "borg-aliyun";
      authorizedKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOvwlbYZzoGg+MYu9HyXhTor07AyoAEbRKpUpNi15LVu"
      ];
    };
    hydev = {
      path = "/var/lib/borgbackup/hydev";
      quota = "10G";
      user = "borg-hydev";
      authorizedKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHmsSyeENaYXUWWXDIETEu1u8Ah7zEX8dCcXuGcqWLxQ"
      ];
    };
    projects = {
      path = "/var/lib/borgbackup/projects";
      quota = "100G";
      user = "borg-projects";
      authorizedKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL3wabckxXT3q9ih7Y070OKjI3lf3+VuLrfilj3FzpK8"
      ];
    };
  };

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_14;
    initialScript = pkgs.writeText "synapse-init.sql" ''
      CREATE USER "matrix-synapse";
      CREATE DATABASE "synapse" WITH OWNER "matrix-synapse"
        TEMPLATE template0
        LC_COLLATE = "C"
        LC_CTYPE = "C";
    '';
  };

  services.matrix-synapse = {
    enable = true;
    withJemalloc = true;
    settings = {
      server_name = "lightquantum.me";
      public_baseurl = "https://chat.lightquantum.me";
      listeners = [
        {
          port = 8080;
          bind_addresses = [ "0.0.0.0" ];
          type = "http";
          tls = false;
          x_forwarded = true;
          resources = [{
            names = [ "client" "federation" ];
            compress = false;
          }];
        }
      ];
      database = {
        name = "psycopg2";
        txn_limit = 10000;
        args = {
          user = "matrix-synapse";
          database = "synapse";
          host = "/var/run/postgresql/";
          port = 5432;
          cp_min = 5;
          cp_max = 10;
        };
      };
      url_preview_enabled = true;
      url_preview_ip_range_blacklist = [
        "127.0.0.0/8"
        "10.0.0.0/8"
        "172.16.0.0/12"
        "192.168.0.0/16"
        "100.64.0.0/10"
        "192.0.0.0/24"
        "169.254.0.0/16"
        "192.88.99.0/24"
        "198.18.0.0/15"
        "192.0.2.0/24"
        "198.51.100.0/24"
        "203.0.113.0/24"
        "224.0.0.0/4"
        "::1/128"
        "fe80::/10"
        "fc00::/7"
        "2001:db8::/32"
        "ff00::/8"
        "fec0::/10"
      ];
      max_spider_size = "10M";
      enable_registration = true;
      registrations_require_3pid = [ "email" ];
      registration_requires_token = true;
    };
    extraConfigFiles = [ "/var/keys/homeserver.yaml" ];
  };

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 8080 ];
  networking.firewall.allowedUDPPorts = [ 20423 ];

  # Copy the NixOS configuration file and link it from the resulting system
  # (/run/current-system/configuration.nix). This is useful in case you
  # accidentally delete configuration.nix.
  # system.copySystemConfiguration = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.05"; # Did you read the comment?
}
