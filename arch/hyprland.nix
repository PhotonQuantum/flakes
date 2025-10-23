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
        ", preferred, auto, 1"
      ];

      # Programs
      "$menu" = "walker";
      "$terminal" = "ghostty";
      "$fileManager" = "dolphin";

      # Autostart

      # https://wiki.hypr.land/Configuring/Variables/#general
      general = {
        gaps_in = 0;
        gaps_out = 0;

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
          size = 3;
          passes = 1;

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
          name = "apple-inc.-magic-trackpad";
          accel_profile = "custom 0.781 0.000 0.099 0.260 0.483 0.768 1.114 1.523 1.993 2.524 3.118 3.774 4.491 5.270 6.111 7.013 7.978 9.004 10.092 11.242 12.453 13.727 15.062 16.459 17.918 19.439 21.021 22.665 24.371 26.139 27.969 29.860 31.813 33.828 35.905 38.044 40.244 42.506 44.830 47.216 49.664 52.173 54.744 57.377 60.072 62.829 65.647 68.527 71.469 74.473 77.538 80.666 83.855 87.106 90.419 93.793 97.230 100.728 104.288 107.910 111.593 115.338 119.146 123.015 126.945";
          scroll_points = "0.781 0.000 0.103 0.238 0.406 0.606 0.839 1.104 1.401 1.731 2.094 2.489 2.918 3.379 3.873 4.399 4.959 5.552 6.178 6.837 7.529 8.254 9.013 9.805 10.630 11.489 12.381 13.307 14.266 15.259 16.285 17.346 18.440 19.568 20.730 21.926 23.155 24.419 25.717 27.049 28.416 29.816 31.251 32.720 34.224 35.762 37.334 38.942 40.583 42.260 43.971 45.717 47.498 49.313 51.164 53.049 54.970 56.925 58.916 60.942 63.003 65.100 67.232 69.399 71.601";
        }
      ];

      # Keybindings
      # See https://wiki.hypr.land/Configuring/Keywords/
      "$mainMod" = "ALT";
      "$superMod" = "CTRL";

      # Example binds, see https://wiki.hypr.land/Configuring/Binds/ for more
      bind = [
        "$superMod, space, exec, $menu"
        "$superMod, return, exec, $terminal"

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
        "suppressevent maximize, class:.*" # ignore maximize events
        "nofocus,class:^$,title:^$,xwayland:1,floating:1,fullscreen:0,pinned:0" # fix dragging issues with wayland
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
    SDL_VIDEODRIVER = "wayland";
    CLUTTER_BACKEND = "wayland";

    XCURSOR_SIZE = "24";
    HYPRCURSOR_SIZE = "24";
  };
  xdg.configFile."uwsm/env".source =
    "${config.home.sessionVariablesPackage}/etc/profile.d/hm-session-vars.sh";
}
