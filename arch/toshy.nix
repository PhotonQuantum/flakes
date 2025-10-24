{ lib, pkgs, ... }:
let
  toshy_config_manager = pkgs.writers.writePython3 "toshy-config-manager" {
    flakeIgnore = [ "E501" "E265" ];
  } (builtins.readFile ./toshy/toshy_config_manager.py);
in
{
  home.activation.toshyApply = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # apply toshy configuration
    echo "applying toshy configuration..." >&2
    $DRY_RUN_CMD ${toshy_config_manager} --apply --config-file ${./toshy/user_config.py}
  '';
}
