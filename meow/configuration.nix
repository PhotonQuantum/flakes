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
    defaultGateway = "10.0.1.1";
    nameservers = [ "1.1.1.1" "1.0.0.1" ];
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

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ ];
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
