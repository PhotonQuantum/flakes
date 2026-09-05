{
  config,
  lib,
  pkgs,
  vmTailscale,
  ...
}:
let
  advertiseTagFlags = lib.optional (
    vmTailscale.tags or [ ] != [ ]
  ) "--advertise-tags=${lib.concatStringsSep "," vmTailscale.tags}";
in
{
  services.tailscale = {
    enable = true;
    authKeyFile = "/var/keys/tailscale-auth-key";
    extraUpFlags = [ "--hostname=${config.networking.hostName}" ] ++ advertiseTagFlags;
    extraSetFlags = [ "--hostname=${config.networking.hostName}" ];
    openFirewall = true;
  };

  # Avoid starting Tailscale while its initial network snapshot can still be empty.
  systemd.network.wait-online.enable = true;
  systemd.network.networks."10-uplink".linkConfig = {
    RequiredForOnline = "routable";
    RequiredFamilyForOnline = "ipv4";
  };
  systemd.services.tailscaled = {
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
  };

  # A live daemon stuck in NoState does not trigger Restart=on-failure.
  # Check before autoconnect, which otherwise only waits until it times out.
  systemd.services.tailscale-startup-check = {
    description = "Recover Tailscale from a stuck initial network state";
    wantedBy = [ "multi-user.target" ];
    wants = [ "tailscaled.service" ];
    after = [ "tailscaled.service" ];
    before = [
      "tailscaled-autoconnect.service"
      "tailscale-advertise-tags.service"
    ];
    path = [
      config.services.tailscale.package
      pkgs.jq
      pkgs.coreutils
      pkgs.systemd
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = "3min";
    };
    script = ''
      for attempt in 0 1 2; do
        for poll in $(seq 1 15); do
          state=$(timeout 5 tailscale status --json --peers=false | jq -er '.BackendState')
          if [[ "$state" != NoState ]]; then
            echo "Tailscale left NoState: $state"
            exit 0
          fi
          sleep 2
        done
        if [[ "$attempt" == 2 ]]; then
          echo "Tailscale remains in NoState after two restarts" >&2
          exit 1
        fi
        echo "Tailscale stuck in NoState; restarting daemon (attempt $((attempt + 1))/2)"
        systemctl restart tailscaled.service
      done
    '';
  };

  # Tailscale CLI only accepts --advertise-tags on `tailscale up`,
  # and the tailscale module only runs `tailscale up` when the node is not authenticated.
  # We reconcile tags separately for existing nodes.
  systemd.services.tailscale-advertise-tags = lib.mkIf (advertiseTagFlags != [ ]) {
    description = "Reconcile Tailscale advertised tags";
    after = [
      "tailscaled-autoconnect.service"
      "tailscaled-set.service"
    ];
    wants = [
      "tailscaled-autoconnect.service"
      "tailscaled-set.service"
    ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${lib.getExe config.services.tailscale.package} up ${
        lib.escapeShellArgs ([ "--hostname=${config.networking.hostName}" ] ++ advertiseTagFlags)
      }
    '';
  };
}
