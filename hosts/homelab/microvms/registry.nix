{
  bridgeGroups = {
    routed = {
      groupId = 1;
      bridgeName = "microvm";
      ipv4Prefix = "10.200.0";
      cidr = 24;
      gatewayHost = 1;
      isolated = false;
      natEnabled = true;
    };
    isolated = {
      groupId = 2;
      bridgeName = "microvm-iso";
      ipv4Prefix = "10.201.0";
      cidr = 24;
      gatewayHost = 1;
      isolated = true;
      natEnabled = true;
    };
  };

  machines = {
    static-http = {
      group = "routed";
      vmId = 10;
      module = ./vms/static-http.nix;
      mem = 512;
      vcpu = 1;
      # Optional per-VM data volume:
      # dataVolume = {
      #   sizeMiB = 1024;
      #   # Optional; defaults to "/mnt".
      #   mountPoint = "/mnt";
      #   # Image path is fixed to "/srv/microvms/${name}/image.img".
      #   # Optional; defaults to "ext4".
      #   fsType = "ext4";
      #   # Optional; defaults to null.
      #   label = "static-http-data";
      # };
    };
    routed-peer-http = {
      group = "routed";
      vmId = 11;
      module = ./vms/routed-peer-http.nix;
      mem = 512;
      vcpu = 1;
    };
    experiment-http = {
      group = "isolated";
      vmId = 10;
      module = ./vms/experiment-http.nix;
      mem = 512;
      vcpu = 1;
    };
    isolated-peer-http = {
      group = "isolated";
      vmId = 11;
      module = ./vms/isolated-peer-http.nix;
      mem = 512;
      vcpu = 1;
    };
  };
}
