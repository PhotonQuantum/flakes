{ pkgs, lib, osConfig, config, ... }:
let
  configOnly = config.home.configOnly or false;
in {
  programs.fish = {
    enable = true;
    # NOTE this.package is required to generate configs.
    # package = if configOnly then pkgs.emptyDirectory else pkgs.fish;
    shellAliases = {
      vim = "nvim";
    };
    shellAbbrs = {
      lf = "yy";
    } // import ./fish/git_abbr.nix;
    functions = {
      lfcd = ''
        set tmp (mktemp)
        # `command` is needed in case `lfcd` is aliased to `lf`
        command lf -last-dir-path=$tmp $argv
        if test -f "$tmp"
            set dir (cat $tmp)
            rm -f $tmp
            if test -d "$dir"
                if test "$dir" != (pwd)
                    cd $dir
                end
            end
        end
      '';
      fish_greeting = "";
      fish_right_prompt = "";
      fish_prompt_loading_indicator = {
        argumentNames = "last_prompt";
        body = ''
          echo -n "$last_prompt" | head -n2 | tail -n1 | read -zl last_prompt_line
          echo -n "$last_prompt_line" | cut -d, -f1-2 | read -l last_prompt_directory

          starship module directory | read -zl current_prompt_directory

          echo
          if [ "$last_prompt_directory" = "$current_prompt_directory" ]
              echo "$last_prompt" | tail -n2
          else
              echo "$current_prompt_directory"
              starship module character
          end
        '';
      };
    };
    interactiveShellInit = ''
      set fish_escape_delay_ms 300
      test -r ~/.opam/opam-init/init.fish && source ~/.opam/opam-init/init.fish > /dev/null 2> /dev/null; or true
    '';
    shellInitLast = if configOnly then ''
      eval (starship init fish)
    '' else ''
      eval (${lib.getExe pkgs.starship} init fish)
    '';
    # + builtins.readFile ./fish/wezterm.fish;
    loginShellInit =
      ''
        set fish_user_paths $fish_user_paths
      '';
    plugins = [
      {
        name = "Done";
        inherit (pkgs.generated.fish_done) src;
      }
      {
        name = "sponge";
        inherit (pkgs.generated.fish_sponge) src;
      }
      {
        name = "autopairs";
        inherit (pkgs.generated.fish_autopairs) src;
      }
      {
        name = "puffer_fish";
        inherit (pkgs.generated.fish_puffer_fish) src;
      }
      {
        name = "async_prompt";
        inherit (pkgs.generated.fish_async_prompt) src;
      }
      {
        name = "abbreviation_tips";
        inherit (pkgs.generated.fish_abbreviation_tips) src;
      }
      {
        name = "jump";
        inherit (pkgs.generated.fish_jump) src;
      }
      {
        name = "sudope";
        inherit (pkgs.generated.fish_sudope) src;
      }
    ];
  };
}
