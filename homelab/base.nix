{ lib, modulesPath, ... }:

{
  # only add strictly necessary modules
  # disabledModules = [
  #   (modulesPath + "/profiles/all-hardware.nix")
  #   (modulesPath + "/profiles/base.nix")
  # ];

  imports = [
    (modulesPath + "/profiles/headless.nix")
    (modulesPath + "/profiles/minimal.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot = {
    # use latest kernel
    # kernelPackages = pkgs.linuxPackages_latest;
    supportedFilesystems = [
      "ext4"
    ];
    growPartition = true;
    kernelModules = [ "kvm-amd" ];
    kernelParams = lib.mkForce [ ];

    loader = {
      grub = {
        enable = true;
        devices = [ "nodev" ];
      };
      # wait for 3 seconds to select the boot entry
      # timeout = lib.mkForce 3;
    };

    initrd = {
      availableKernelModules = [ "uhci_hcd" "ehci_pci" "ahci" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" ];
    };

    # clear /tmp on boot to get a stateless /tmp directory.
    tmp.cleanOnBoot = true;
  };

  services.qemuGuest.enable = true;

  networking.useDHCP = lib.mkDefault true;

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    autoResize = true;
    fsType = "ext4";
  };

  # reduce size of the VM
  services.fstrim = {
    enable = true;
    interval = "weekly";
  };

  # disable useless software
  environment.defaultPackages = [ ];
  xdg.icons.enable = false;
  xdg.mime.enable = false;
  xdg.sounds.enable = false;

  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
    };
    # garbage collection
    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete older-than 3d";
    };
  };
  system.stateVersion = "26.05";
}
