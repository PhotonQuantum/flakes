{ lib, pkgs, ... }:
{
  xdg.configFile."aerospace/aerospace.toml" =
    let
      sketchybar = "${pkgs.sketchybar}/bin/sketchybar";
      aerospace-settings = {
        # managed by nix-darwin
        start-at-login = false;
        enable-normalization-flatten-containers = true;
        enable-normalization-opposite-orientation-for-nested-containers = true;
        accordion-padding = 30;
        default-root-container-layout = "accordion";
        default-root-container-orientation = "auto";
        on-focused-monitor-changed = [ "move-mouse monitor-lazy-center" ];
        key-mapping.preset = "qwerty";

        automatically-unhide-macos-hidden-apps = true;
        after-startup-command = [
          "move-workspace-to-monitor --workspace 6 --wrap-around next"
          "workspace 1"
        ];

        # TODO pkgs if we move sketchybar to nix
        exec-on-workspace-change = [
          "/bin/bash"
          "-c"
          "${sketchybar} --trigger aerospace_workspace_change FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE"
        ];
        on-focus-changed = [
          "exec-and-forget ${sketchybar} --trigger aerospace_focus_change"
        ];
        on-window-detected = [
          {
            "if".app-name-regex-substring = "qq|wechat|telegram";
            run = [ "move-node-to-workspace 4" ];
          }
          {
            "if".app-name-regex-substring = "slack|discord|zulip|element";
            run = [ "move-node-to-workspace 5" ];
          }
          {
            "if".app-name-regex-substring = "code";
            run = [ "move-node-to-workspace --focus-follows-window 3" ];
          }
          {
            "if".app-name-regex-substring = "arc";
            run = [ "move-node-to-workspace --focus-follows-window 2" ];
          }
        ];

        gaps = {
          inner.horizontal = 10;
          inner.vertical = 10;
          outer.left = 5;
          outer.bottom = 45;
          outer.top = 5;
          outer.right = 5;
        };
        # 'main' binding mode declaration
        # See: https://nikitabobko.github.io/AeroSpace/guide#binding-modes
        # 'main' binding mode must be always presented
        # Fallback value (if you omit the key): mode.main.binding = {}
        mode.main.binding =
          {
            # All possible keys:
            # - Letters.        a, b, c, ..., z
            # - Numbers.        0, 1, 2, ..., 9
            # - Keypad numbers. keypad0, keypad1, keypad2, ..., keypad9
            # - F-keys.         f1, f2, ..., f20
            # - Special keys.   minus, equal, period, comma, slash, backslash, quote, semicolon, backtick,
            #                   leftSquareBracket, rightSquareBracket, space, enter, esc, backspace, tab
            # - Keypad special. keypadClear, keypadDecimalMark, keypadDivide, keypadEnter, keypadEqual,
            #                   keypadMinus, keypadMultiply, keypadPlus
            # - Arrows.         left, down, up, right

            # All possible modifiers: cmd, alt, ctrl, shift

            # All possible commands: https://nikitabobko.github.io/AeroSpace/commands

            cmd-enter =
              let
                script = pkgs.writeText "ghostty.applescript" ''
                  tell application "Ghostty"
                    if it is running then
                      activate
                      tell application "System Events" to keystroke "n" using {command down}
                    else
                      activate
                    end if
                  end tell
                '';
              in
              "exec-and-forget osascript ${script}";

            alt-w = "close";

            # See: https://nikitabobko.github.io/AeroSpace/commands#layout
            alt-slash = "layout tiles horizontal vertical";
            alt-comma = "layout accordion horizontal vertical";

            # See: https://nikitabobko.github.io/AeroSpace/commands#focus
            alt-h = "focus left";
            alt-j = "focus down";
            alt-k = "focus up";
            alt-l = "focus right";

            # See: https://nikitabobko.github.io/AeroSpace/commands#move
            alt-shift-h = "move left";
            alt-shift-j = "move down";
            alt-shift-k = "move up";
            alt-shift-l = "move right";

            alt-m = "focus-monitor --wrap-around next";
            alt-shift-m = "move-node-to-monitor --wrap-around next";

            # See: https://nikitabobko.github.io/AeroSpace/commands#resize
            alt-shift-minus = "resize smart -50";
            alt-shift-equal = "resize smart +50";

            # See: https://nikitabobko.github.io/AeroSpace/commands#workspace-back-and-forth
            alt-tab = "workspace-back-and-forth";
            # See: https://nikitabobko.github.io/AeroSpace/commands#move-workspace-to-monitor
            alt-shift-tab = "move-workspace-to-monitor --wrap-around next";

            # See: https://nikitabobko.github.io/AeroSpace/commands#mode
            alt-shift-semicolon = "mode service";
          }
          // (lib.lists.foldl' (
            acc: letter:
            acc
            // {
              # See: https://nikitabobko.github.io/AeroSpace/commands#workspace
              "alt-${lib.strings.toLower letter}" = "workspace ${letter}";
              # See: https://nikitabobko.github.io/AeroSpace/commands#move-node-to-workspace
              "alt-shift-${lib.strings.toLower letter}" = "move-node-to-workspace ${letter}";
            }
          ) { } (lib.strings.stringToCharacters "123456789ABCDEFGINOPQRSTUVXYZ"));

        # 'service' binding mode declaration.
        # See: https://nikitabobko.github.io/AeroSpace/guide#binding-modes
        mode.service.binding = {
          esc = [
            "reload-config"
            "mode main"
          ];
          r = [
            "flatten-workspace-tree"
            "mode main"
          ]; # reset layout
          f = [
            "layout floating tiling"
            "mode main"
          ]; # Toggle between floating and tiling layout
          backspace = [
            "close-all-windows-but-current"
            "mode main"
          ];

          # sticky is not yet supported https://github.com/nikitabobko/AeroSpace/issues/2
          # s = ["layout sticky tiling" "mode main"];

          alt-shift-h = [
            "join-with left"
            "mode main"
          ];
          alt-shift-j = [
            "join-with down"
            "mode main"
          ];
          alt-shift-k = [
            "join-with up"
            "mode main"
          ];
          alt-shift-l = [
            "join-with right"
            "mode main"
          ];
          alt-shift-f = [
            "fullscreen"
            "mode main"
          ];

          down = "volume down";
          up = "volume up";
          shift-down = [
            "volume set 0"
            "mode main"
          ];
        };
      };
      format = pkgs.formats.toml { };
    in
    {
      source = (format.generate "aerospace.toml" aerospace-settings);
      onChange = "${pkgs.aerospace}/bin/aerospace reload-config";
    };
}
