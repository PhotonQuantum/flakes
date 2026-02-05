#!/usr/bin/env python3
"""
Toshy Custom Configuration

This file stores your custom configurations extracted from toshy_config.py.
Edit the content between the triple quotes for each section.

Generated: 2025-11-09 01:33:19
"""

# Dictionary mapping section names to their custom content
slices = {
    'env_overrides': '''





# MANUALLY set any environment information if the auto-identification isn't working:
OVERRIDE_DISTRO_ID              = None
OVERRIDE_DISTRO_VER             = None
OVERRIDE_VARIANT_ID             = None
OVERRIDE_SESSION_TYPE           = None
OVERRIDE_DESKTOP_ENV            = None
OVERRIDE_DE_MAJ_VER             = None
OVERRIDE_WINDOW_MGR             = None

wlroots_compositors             = [
    # Comma-separated list of Wayland desktop environments or window managers
    # that should try to use the 'wlroots' window context provider. Use the 
    # 'WINDOW_MGR' name that appears when running `toshy-env`, or 'DESKTOP_ENV'
    # if the window manager name is not identified. 
    # 'obscurewm',
    # 'unknown-wm',

]

''',

    'exclude_kpad_devs': '''





# List of devices to add to the device exclusion list below this slice

exclude_kpad_devs_UserCustom_lst = [
    # Example syntax:
    # 'My Keyboard Device',

]

''',

    'kbtype_override': '''





keyboards_UserCustom_dct = {
    # Add your keyboard device here if its type is misidentified.
    # Valid types to map device to: Apple, Windows, IBM, Chromebook (case sensitive)
    # Example:
    'Compx Flow84@Lofree': 'Apple',
}

''',

    'keymapper_api': '''





# Keymapper-specific config settings - REMOVE OR SET TO DEFAULTS FOR DISTRIBUTION
dump_diagnostics_key(Key.F15)   # default key: F15
emergency_eject_key(Key.F16)    # default key: F16

timeouts(
    multipurpose        = 1,        # default: 1 sec
    suspend             = 0.3,        # default: 1 sec, try 0.1 sec for touchpads/trackpads
)

# Delays often needed for Wayland and/or virtual machines or slow systems
throttle_delays(
    key_pre_delay_ms    = 12,      # default: 0 ms, range: 0-150 ms, suggested: 1-50 ms
    key_post_delay_ms   = 18,      # default: 0 ms, range: 0-150 ms, suggested: 1-100 ms
)

devices_api(
    # Only the specified devices will be "grabbed" and watched for duringa  
    # device connections/disconnections. 
    only_devices = [
        # 'Example Disconnected Keyboard',
        # 'Example Connected Keyboard',
    ]
)

###########################################################
# If you need to use something like the wordwise 'emacs' 
# style shortcuts, and want them to be repeatable, use
# the API call below to stop the keymapper from ignoring
# "repeat" key events. This will use a bit more CPU while
# holding any key down, especially while holding a key combo
# that is getting remapped onto something else in the config.
###########################################################
# ignore_repeating_keys(False)


''',

    'user_apps': '''






keymap("User hardware keys", {
    # PUT UNIVERSAL REMAPS FOR HARDWARE KEYS HERE
    # KEYMAP WILL BE ACTIVE IN ALL DESKTOP ENVIRONMENTS/DISTROS


}, when = lambda ctx:
    cnfg.screen_has_focus and
    matchProps(not_clas=remoteStr)(ctx)
)

if DESKTOP_ENV == "hyprland":
    keymap("User overrides general", {
        C("RC-Space"):             [iEF2NT(),C("C-p")],
    }, when = lambda ctx:
        cnfg.screen_has_focus and
        matchProps(not_clas=remoteStr)(ctx)
    )

keymap("User overrides: VSCodes overrides for not Chromebook/IBM", {
    C("LC-c"):               C("Super-c"),                   # Default - Terminal - Sigint
    C("LC-x"):               C("Super-x"),                   # Default - Terminal - Exit nano
}, when = lambda ctx:
    cnfg.screen_has_focus and
    not (   isKBtype('Chromebook', map="vscodes ovr not cbook")(ctx) or 
            isKBtype('IBM', map="vscodes ovr not ibm")(ctx) ) and
    matchProps(clas=vscodeStr)(ctx)
)

keymap("User overrides VSCodes", {
    C("RC-Enter"):              C("C-Enter"),
}, when = lambda ctx:
    cnfg.screen_has_focus and
    matchProps(clas=vscodeStr)(ctx)
)

# Keybindings for IntelliJ
keymap("User overrides Jetbrains", {
    # General
    C("LC-w"):                   C("C-w"),                      # Close active editor tab
    C("RC-w"):                   C("C-F4"),                      # Close active editor tab
}, when = lambda ctx:
    cnfg.screen_has_focus and
    matchProps(clas="^jetbrains-(?!.*toolbox).*$")(ctx) )

''',

    'user_custom_functions': '''







''',

    'user_custom_lists': '''







''',

    'user_custom_modmaps': '''





modmap("Cond modmap - Terms - Mac kbd", {
    Key.CAPSLOCK:               Key.LEFT_CTRL,
    Key.LEFT_CTRL:              Key.CAPSLOCK,
}, when = lambda ctx:
    cnfg.screen_has_focus and
    matchProps(not_clas=remoteStr)(ctx)
)

''',

}
