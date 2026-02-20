{
  lib,
  homelabSecrets,
  resolvedGroups,
  resolvedMachines,
}:
{
  imports = [
    (import ./common.nix {
      inherit
        lib
        homelabSecrets
        resolvedGroups
        resolvedMachines
        ;
    })
    (import ./isolation.nix {
      inherit
        lib
        homelabSecrets
        resolvedGroups
        ;
    })
  ];
}
