{ pkgs, ... }:
{
  programs.yazi = {
    enable = true;
    keymap = {
      mgr.prepend_keymap =
        [
          {
            on = [ "<S-Enter>" ];
            run = "escape";
            desc = "Exit visual mode, clear selected, or cancel search";
          }
          {
            on = [ "<Enter>" ];
            run = "noop";
            desc = "";
          }
          {
            on = [ "l" ];
            run = "plugin smart-enter";
            desc = "Enter the child directory, or open the file";
          }
        ]
        ++ builtins.genList (n: {
          on = [ (toString n) ];
          run = "plugin relative-motions ${toString n}";
          desc = "Move in relative steps";
        }) 9;
      input.prepend_keymap = [
        {
          on = [ "<S-Enter>" ];
          run = "escape";
          desc = "Go back the normal mode, or cancel input";
        }
        {
          on = [ "H" ];
          run = "move -999";
          desc = "Move to the BOL";
        }
        {
          on = [ "L" ];
          run = "move 999";
          desc = "Move to the EOL";
        }
      ];
      pick.prepend_keymap = [
        {
          on = [ "<S-Enter>" ];
          run = "close";
          desc = "Cancel the picker";
        }
        {
          on = [ "h" ];
          run = "close";
          desc = "Cancel the picker";
        }
      ];
    };
    settings = {
      mgr = {
        ratio = [
          1
          2
          3
        ];
        show_symlink = false;
        preview = {
          wrap = "yes";
        };
      };
      plugin = {
        prepend_fetchers = [
          {
            id = "git";
            name = "*";
            run = "git";
          }
          {
            id = "git";
            name = "*";
            run = "git";
          }
        ];
      };
    };
    flavors = with pkgs.generated; {
      catppuccin-latte = "${yazi_flavors.src}/catppuccin-latte.yazi";
      catppuccin-mocha = "${yazi_flavors.src}/catppuccin-mocha.yazi";
    };
    plugins = {
      inherit (pkgs.yaziPlugins) relative-motions git starship;
      smart-enter = ./yazi/smart-enter.yazi; # NOTE: forked version
    };
    initLua = ./yazi/init.lua;
    theme = {
      flavor = {
        light = "catppuccin-latte";
        dark = "catppuccin-mocha";
      };
    };
  };
}
