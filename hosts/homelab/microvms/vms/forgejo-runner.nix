{ pkgs, ... }:
let
  secrets = import ../../../../secrets/homelab.nix;

  package = pkgs.forgejo-runner;
  secret = secrets.forgejo.runnerSecret;
  url = "https://git.lightquantum.me";

  settings = {
    runner = {
      labels = [
        "ubuntu-latest:docker://ghcr.io/catthehacker/ubuntu:act-latest"
        "ubuntu-24.04:docker://ghcr.io/catthehacker/ubuntu:act-24.04"
        "ubuntu-22.04:docker://ghcr.io/catthehacker/ubuntu:act-22.04"
      ];
      capacity = 2;
    };
    container.docker_host = "automount";
  };

  settingsFormat = pkgs.formats.yaml { };
  configFile = settingsFormat.generate "config.yaml" settings;

  runnerRoot = "/mnt/forgejo-runner";
  runnerUser = "forgejo-runner";
in
{
  services.gitea-actions-runner.package = pkgs.forgejo-runner;

  virtualisation.docker = {
    enable = true;
    daemon.settings = {
      data-root = "/mnt/docker";
    };
  };

  users = {
    users.${runnerUser} = {
      description = "Forgejo Actions Runner";
      isSystemUser = true;
      group = runnerUser;
      useDefaultShell = true;
      home = runnerRoot;
    };
    groups.${runnerUser} = {
      name = runnerUser;
      members = [ runnerUser ];
    };
  };

  systemd.services.forgejo-runner = {
    enable = true;
    wants = [ "network-online.target" ];
    after = [
      "network-online.target"
      "docker.service"
    ];
    wantedBy = [
      "multi-user.target"
    ];
    environment = {
      HOME = "/mnt/forgejo-runner";
    };
    path = [ pkgs.coreutils ];
    serviceConfig = {
      User = runnerUser;
      WorkingDirectory = "-${runnerRoot}";

      # forgejo-runner might fail when forgejo is restarted during upgrade.
      Restart = "on-failure";
      RestartSec = 2;

      ExecStartPre = [
        (pkgs.writeShellScript "forgejo-register-runner" ''
          # perform the registration
          ${package}/bin/act_runner create-runner-file --instance ${url} --secret ${secret} --config ${configFile}
        '')
      ];
      ExecStart = "${package}/bin/act_runner daemon --config ${configFile}";
      SupplementaryGroups = [ "docker" ];
    };
  };

  systemd.tmpfiles.rules = [
    "d /mnt/docker 0710 root root - -"
    "d ${runnerRoot} 0750 ${runnerUser} ${runnerUser} - -"
  ];

  networking.firewall.trustedInterfaces = [ "br-+" ];
}
