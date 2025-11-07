{ lib, pkgs, ... }:
let
  toggle_special_workspace = ''
    #!/usr/bin/env bash

    AEROSPACE="${lib.getExe pkgs.aerospace}"

    STATE_DIR="$HOME/.local/state/aerospace-toggle-special-workspace"
    PREV_WORKSPACE_FILE="$STATE_DIR/prev_workspace"

    mkdir -p "$STATE_DIR"

    OLD_WORKSPACE=$($AEROSPACE list-workspaces --focused)

    # try to summon the special workspace
    $AEROSPACE summon-workspace --fail-if-noop "S"
    SUMMON_RESULT=$?

    if [ $SUMMON_RESULT -eq 0 ]; then
        # Successfully summoned the special workspace

        # Save the old workspace to file
        echo "$OLD_WORKSPACE" > "$PREV_WORKSPACE_FILE"
    else
        # Failed to summon, so we presumably are already in the special workspace
        # Switch back to the previous workspace

        # Read the previous workspace from file if it exists
        if [ -f "$PREV_WORKSPACE_FILE" ]; then
            TARGET_WORKSPACE=$(cat "$PREV_WORKSPACE_FILE")
        else
            # If no previous workspace is recorded, switch to the first workspace of current monitor
            TARGET_WORKSPACE=$($AEROSPACE list-workspaces --monitor focused | head -n1)
        fi

        $AEROSPACE workspace "$TARGET_WORKSPACE"
    fi
  '';
  script = pkgs.writeText "toggle_special_workspace.sh" toggle_special_workspace;
in
{
  programs.aerospace.userSettings = {
    mode.main.binding = {
      "alt-s" = "exec-and-forget bash ${script}";
      "alt-shift-s" = "move-node-to-workspace S";
    };
  };
}
