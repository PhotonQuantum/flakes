{
  lib,
  certDefaults,
  resolvedMachines,
  volumePath,
}:
let
  vmLib = import ./lib.nix { inherit lib; };
  acmeEmail =
    certDefaults.email or (throw "certDefaults.email is required for host ACME provisioning");
  allMachineConfigs = builtins.attrValues resolvedMachines;
  certMachineConfigs = builtins.filter (machine: machine.certResolved.enabled) allMachineConfigs;
  certShareRoot = "${volumePath}/certs";
  mkCertPostRun =
    machine:
    let
      cert = machine.certResolved;
    in
    ''
      set -eu

      target=${lib.escapeShellArg cert.hostSharePath}
      tmp="$(mktemp -d "$target/.new.XXXXXX")"
      cleanup() {
        rm -rf "$tmp"
      }
      trap cleanup EXIT

      install -m 0644 -o root -g ${lib.escapeShellArg vmLib.certGroup} fullchain.pem "$tmp/fullchain.pem"
      install -m 0644 -o root -g ${lib.escapeShellArg vmLib.certGroup} cert.pem "$tmp/cert.pem"
      install -m 0644 -o root -g ${lib.escapeShellArg vmLib.certGroup} chain.pem "$tmp/chain.pem"
      install -m 0640 -o root -g ${lib.escapeShellArg vmLib.certGroup} key.pem "$tmp/key.pem"

      mv -f "$tmp/fullchain.pem" "$target/fullchain.pem"
      mv -f "$tmp/cert.pem" "$target/cert.pem"
      mv -f "$tmp/chain.pem" "$target/chain.pem"
      mv -f "$tmp/key.pem" "$target/key.pem"
      rmdir "$tmp"
      trap - EXIT
    '';
  acmeCerts = builtins.listToAttrs (
    map (
      machine:
      let
        cert = machine.certResolved;
      in
      {
        name = cert.domain;
        value = {
          domain = cert.domain;
          extraDomainNames = cert.extraDomainNames;
          group = vmLib.certGroup;
          postRun = mkCertPostRun machine;
        };
      }
    ) certMachineConfigs
  );
in
{
  systemd.tmpfiles.rules = [
    "d ${certShareRoot} 0755 root root - -"
  ]
  ++ (map (
    machine: "d ${machine.certResolved.hostSharePath} 0750 root ${vmLib.certGroup} - -"
  ) certMachineConfigs);

  users.groups.${vmLib.certGroup} = lib.mkIf (certMachineConfigs != [ ]) {
    gid = vmLib.certGroupGid;
  };

  security.acme = {
    acceptTerms = true;
    defaults = {
      email = acmeEmail;
      dnsProvider = "cloudflare";
      dnsResolver = "1.1.1.1:53";
      environmentFile = "/var/keys/cloudflare-acme.env";
    };
    certs = acmeCerts;
  };
}
