{ vmBeszelExtraFilesystems, ... }:
{
  imports = [
    (import ../../beszel-agent.nix {
      environmentFile = "/var/keys/beszel-agent.env";
      installKeysService = "microvm-install-keys.service";
      extraFilesystems = vmBeszelExtraFilesystems;
    })
  ];
}
