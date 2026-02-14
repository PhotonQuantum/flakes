{ lib, pkgs, ... }:
{
  programs.aerospace.settings =
    let
      aerospace-marks = lib.getExe' pkgs.aerospace-marks "aerospace-marks";
    in
    {
      mode.main.binding = {
        "alt-m" = "mode mark";
        "alt-quote" = "mode jump";
      };

      mode.mark.binding =
        (lib.lists.foldl' (
          acc: letter:
          acc
          // {
            "${letter}" = [
              "exec-and-forget ${aerospace-marks} mark ${letter}"
              "mode main"
            ];
          }
        ) { } (lib.strings.stringToCharacters "1234567890abcdefghijklmnopqrstuvwxyz"))
        // {
          esc = [ "mode main" ];
          shift-enter = [ "mode main" ];
        };

      mode.jump.binding =
        (lib.lists.foldl' (
          acc: letter:
          acc
          // {
            "${letter}" = [
              "exec-and-forget ${aerospace-marks} focus ${letter}"
              "mode main"
            ];
          }
        ) { } (lib.strings.stringToCharacters "1234567890abcdefghijklmnopqrstuvwxyz"))
        // {
          esc = [ "mode main" ];
          shift-enter = [ "mode main" ];
        };
    };
}
