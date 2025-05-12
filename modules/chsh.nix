{ config, lib, ... }:

with lib;

{
  options = {
    home.defaultShell = mkOption {
      type = with types; nullOr path;
      default = null;
      example = literalExpression (lib.getExe pkgs.fish);
    };
  };
  config = {
    home.activation.chsh = lib.hm.dag.entryAfter [ "writeBoundary" ] (
      mkIf (config.home.defaultShell != null) ''
        # Set default shell.
        echo "setting default shell..." >&2

        $DRY_RUN_CMD sudo chsh -s ${config.home.defaultShell} ${config.home.username}
      ''
    );
  };
}
