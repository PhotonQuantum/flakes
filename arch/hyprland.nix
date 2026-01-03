{ config, lib, ... }:

let
  genTouchpadCurve =
    c:
    let
      cubic =
        a: b: c: x:
        a * x + b * x * x + c * x * x * x;
      step = c.maxSpeed * 1.0 / c.samplePointCount;
      speeds = builtins.genList (i: step * i) c.samplePointCount;
      factors = builtins.map (cubic c.accelLow c.accelMid c.accelHigh) speeds;
    in
    {
      inherit step speeds factors;
    };

  genTouchpadDeviceBlock =
    device: c:
    let
      roundTo3 = x: builtins.toString (builtins.floor (x * 1000 + 0.5) / 1000.0);
      seqToStr = seq: builtins.concatStringsSep " " (builtins.map roundTo3 seq);
      r = genTouchpadCurve c;
    in
    {
      name = device;
      accel_profile = "custom ${toString r.step} ${seqToStr r.factors}";
      scroll_points = "${toString r.step} ${seqToStr r.factors}";
    };
in
{
  wayland.windowManager.hyprland = {
    enable = true;
    package = null;
    portalPackage = null;

    settings = {
      # Monitors
      monitor = [
        "desc:Dell Inc. DELL U2718Q, preferred, auto, 2"
        "desc:LG Electronics LG ULTRAFINE 105NTMXHK739, preferred, auto, 2"
        ", preferred, auto, 1"
      ];

      # Programs
      "$menu" = "walker";
      "$terminal" = "ghostty";
      "$fileManager" = "dolphin";
      "$screenshot" = "qsview";

      # Autostart

      # https://wiki.hypr.land/Configuring/Variables/#general
      general = {
        gaps_in = 2;
        gaps_out = 6;

        border_size = 3;

        # https://wiki.hypr.land/Configuring/Variables/#variable-types for info about colors
        "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
        "col.inactive_border" = "rgba(595959aa)";

        # Set to true enable resizing windows by clicking and dragging on borders and gaps
        resize_on_border = true;

        # Please see https://wiki.hypr.land/Configuring/Tearing/ before you turn this on
        allow_tearing = false;

        layout = "dwindle";
      };

      misc = {
        focus_on_activate = true;
      };

      # https://wiki.hypr.land/Configuring/Variables/#decoration
      decoration = {
        rounding = 10;
        rounding_power = 2;

        # Change transparency of focused and unfocused windows
        active_opacity = 1.0;
        inactive_opacity = 1.0;

        shadow = {
          enabled = true;
          range = 4;
          render_power = 3;
          color = "rgba(1a1a1aee)";
        };

        # https://wiki.hypr.land/Configuring/Variables/#blur
        blur = {
          enabled = true;
          size = 6;
          passes = 2;

          vibrancy = 0.1696;
        };
      };

      # https://wiki.hypr.land/Configuring/Variables/#animations
      animations = {
        enabled = true;

        # Default curves, see https://wiki.hypr.land/Configuring/Animations/#curves
        #        NAME,           X0,   Y0,   X1,   Y1
        bezier = [
          "easeOutQuint,   0.23, 1,    0.32, 1"
          "easeInOutCubic, 0.65, 0.05, 0.36, 1"
          "linear,         0,    0,    1,    1"
          "almostLinear,   0.5,  0.5,  0.75, 1"
          "quick,          0.15, 0,    0.1,  1"
        ];

        # Default animations, see https://wiki.hypr.land/Configuring/Animations/
        #           NAME,          ONOFF, SPEED, CURVE,        [STYLE]
        animation = [
          "global,        1,     10,    default"
          "border,        1,     5.39,  easeOutQuint"
          "windows,       1,     4.79,  easeOutQuint"
          "windowsIn,     1,     4.1,   easeOutQuint, popin 87%"
          "windowsOut,    1,     1.49,  linear,       popin 87%"
          "fadeIn,        1,     1.73,  almostLinear"
          "fadeOut,       1,     1.46,  almostLinear"
          "fade,          1,     3.03,  quick"
          "layers,        1,     3.81,  easeOutQuint"
          "layersIn,      1,     4,     easeOutQuint, fade"
          "layersOut,     1,     1.5,   linear,       fade"
          "fadeLayersIn,  1,     1.79,  almostLinear"
          "fadeLayersOut, 1,     1.39,  almostLinear"
          "workspaces,    1,     1.94,  almostLinear, fade"
          "workspacesIn,  1,     1.21,  almostLinear, fade"
          "workspacesOut, 1,     1.94,  almostLinear, fade"
          "zoomFactor,    1,     7,     quick"
        ];
      };

      # See https://wiki.hypr.land/Configuring/Dwindle-Layout/ for more
      dwindle = {
        pseudotile = true; # Master switch for pseudotiling. Enabling is bound to mainMod + P in the keybinds section below
        preserve_split = true; # You probably want this
      };

      # See https://wiki.hypr.land/Configuring/Master-Layout/ for more
      master = {
        new_status = "master";
      };

      # https://wiki.hypr.land/Configuring/Variables/#misc
      misc = {
        force_default_wallpaper = -1; # Set to 0 or 1 to disable the anime mascot wallpapers
        disable_hyprland_logo = false; # If true disables the random hyprland logo / anime girl background. :(
      };

      # Input
      # https://wiki.hypr.land/Configuring/Variables/#input
      input = {
        kb_layout = "us";
        kb_variant = "";
        kb_model = "";
        kb_options = "";
        kb_rules = "";

        follow_mouse = 1;

        sensitivity = 0; # -1.0 - 1.0, 0 means no modification.

        touchpad = {
          disable_while_typing = true;
          clickfinger_behavior = true;
          natural_scroll = true;
          tap-to-click = false;
          scroll_factor = 0.15;
        };
      };

      device = [
        {
          name = "apple-inc.-magic-trackpad-usb-c";
          accel_profile = "custom 0.469 0.000 0.052 0.127 0.223 0.342 0.483 0.647 0.832 1.040 1.270 1.523 1.797 2.094 2.413 2.754 3.118 3.504 3.912 4.342 4.795 5.270 5.767 6.286 6.828 7.392 7.978 8.586 9.217 9.869 10.544 11.242 11.961 12.703 13.467 14.254 15.062 15.893 16.746 17.621 18.519 19.439 20.381 21.345 22.331 23.340 24.371 25.424 26.500 27.598 28.718 29.860 31.025 32.211 33.420 34.652 35.905 37.181 38.479 39.799 41.141 42.506 43.893 45.302 46.734";
          scroll_points = "0.781 0.000 0.103 0.238 0.406 0.606 0.839 1.104 1.401 1.731 2.094 2.489 2.918 3.379 3.873 4.399 4.959 5.552 6.178 6.837 7.529 8.254 9.013 9.805 10.630 11.489 12.381 13.307 14.266 15.259 16.285 17.346 18.440 19.568 20.730 21.926 23.155 24.419 25.717 27.049 28.416 29.816 31.251 32.720 34.224 35.762 37.334 38.942 40.583 42.260 43.971 45.717 47.498 49.313 51.164 53.049 54.970 56.925 58.916 60.942 63.003 65.100 67.232 69.399 71.601";
        }
      ];

      # Keybindings
      # See https://wiki.hypr.land/Configuring/Keywords/
      "$mainMod" = "ALT";
      "$superMod" = "CTRL";

      # Example binds, see https://wiki.hypr.land/Configuring/Binds/ for more
      bind = [
        "$superMod, p, exec, $menu"
        "$superMod, return, exec, $terminal"
        "$superMod SHIFT, 4, exec, $screenshot"

        "$mainMod, Q, exec, $terminal"
        "$mainMod, C, killactive,"
        "$mainMod, M, exec, uwsm exit"
        "$mainMod, E, exec, $fileManager"
        "$mainMod, V, togglefloating,"
        "$mainMod, R, exec, $menu"
        "$mainMod, P, pseudo," # dwindle
        "$mainMod, J, togglesplit," # dwindle

        # Move focus with mainMod + arrow keys
        "$mainMod, h, movefocus, l"
        "$mainMod, l, movefocus, r"
        "$mainMod, k, movefocus, u"
        "$mainMod, j, movefocus, d"
      ]
      ++ (lib.lists.concatMap (
        i:
        let
          key = toString (lib.mod i 10);
          ws = toString i;
        in
        [
          # Switch workspaces with mainMod + [0-9]
          "$mainMod SHIFT, ${key}, movetoworkspace, ${ws}"
          # Move active window to a workspace with mainMod + SHIFT + [0-9]
          "$mainMod, ${key}, workspace, ${ws}"
        ]
      ) (lib.lists.range 1 10))
      ++ [
        # Example special workspace (scratchpad)
        "$mainMod, S, togglespecialworkspace, magic"
        "$mainMod SHIFT, S, movetoworkspace, special:magic"

        # Scroll through existing workspaces with mainMod + scroll
        "$mainMod, mouse_down, workspace, e+1"
        "$mainMod, mouse_up, workspace, e-1"
      ];

      # Move/resize windows with mainMod + LMB/RMB and dragging
      bindm = [
        "$mainMod, mouse:272, movewindow"
        "$mainMod, mouse:273, resizewindow"
      ];

      # Laptop multimedia keys for volume and LCD brightness
      bindel = [
        ",XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
        ",XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ",XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ",XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
        ",XF86MonBrightnessUp, exec, brightnessctl -e4 -n2 set 5%+"
        ",XF86MonBrightnessDown, exec, brightnessctl -e4 -n2 set 5%-"
      ];

      # Requires playerctl
      bindl = [
        ", XF86AudioNext, exec, playerctl next"
        ", XF86AudioPause, exec, playerctl play-pause"
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioPrev, exec, playerctl previous"
      ];

      exec-once = [
        "uwsm app /usr/lib/pam_kwallet_init"
      ];

      windowrule = [
        {
          name = "ignore_maximize_event";
          suppress_event = "maximize";
          "match:class" = ".*";
        }
        {
          name = "fix_dragging_wayland_floating";
          no_focus = "on";
          "match:class" = "^$";
          "match:title" = "^$";
          "match:xwayland" = 1;
          "match:float" = 1;
          "match:fullscreen" = 0;
          "match:pin" = 0;
        }
        {
          name = "portal_window_float_center";
          float = "on";
          stay_focused = "on";
          center = "on";
          "match:class" = "xdg-desktop-portal-gtk";
        }
        {
          name = "screenshot_tool_float_center";
          float = "on";
          center = "on";
          "match:class" = "be.alexandervanhee.gradia";
        }
        {
          name = "quickshell";
          no_anim = "on";
          "match:class" = "quickshell";
        }
      ];

      layerrule = [
        {
          name = "quickshell";
          blur = "on";
          ignore_alpha = 0.3;
          no_anim = "on";
          "match:namespace" = "quickshell";
        }
      ];
    };

    systemd.variables = [ "--all" ];
  };

  home.activation.hyprlandSystemdUnit = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # Enable hyprland systemd unit.
    echo "enabling hyprland related systemd user units..." >&2
    PATH="$PATH:/usr/bin" $DRY_RUN_CMD systemctl --user enable hyprpolkitagent.service
    PATH="$PATH:/usr/bin" $DRY_RUN_CMD systemctl --user enable swaync.service
  '';

  xdg.configFile."electron-flags.conf".text = ''
    --enable-features=UseOzonePlatform --ozone-platform=wayland
  '';

  home.sessionVariables = {
    LIBVA_DRIVER_NAME = "nvidia";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";

    ELECTRON_OZONE_PLATFORM_HINT = "auto";
    NVD_BACKEND = "direct";

    GDK_BACKEND = "wayland,x11,*";
    QT_QPA_PLATFORM = "wayland;xcb";
    QT_QPA_PLATFORMTHEME = "qt6ct";
    SDL_VIDEODRIVER = "wayland";
    CLUTTER_BACKEND = "wayland";

    XCURSOR_SIZE = "24";
    HYPRCURSOR_SIZE = "24";
  };
  xdg.configFile."uwsm/env".source =
    "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";
}
