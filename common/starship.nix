{ lib, pkgs, ... }:

let
  recursiveMerge =
    with lib;
    attrList:
    let
      f =
        attrPath:
        zipAttrsWith (
          n: values:
          if tail values == [ ] then
            head values
          else if all isList values then
            unique (concatLists values)
          else if all isAttrs values then
            f (attrPath ++ [ n ]) values
          else
            last values
        );
    in
    f [ ] attrList;
  compose_pipe = with pkgs.lib; l: flip pipe (reverseList l);
in
{
  programs.starship = {
    enable = true;
    enableFishIntegration = false; # Fish integration is handled by `fish` module
    settings =
      let
        presets =
          with builtins;
          map
            (compose_pipe [
              fromTOML
              readFile
              (s: ./starship + "/${s}")
            ])
            (
              compose_pipe [
                attrNames
                (lib.filterAttrs (_: kind: kind == "regular"))
                readDir
              ] (./starship)
            );
      in
      {
        git_status = {
          ahead = "↑\${count}";
          behind = "↓\${count}";
          conflicted = "✖";
          diverged = "⇅↑\${ahead_count}↓\${behind_count}";
          modified = "※";
          staged = "✓";
          stashed = "";
          untracked = "";
          ignore_submodules = true;
        };
        ocaml.detect_files = [
          "dune"
          "dune-project"
          "jbuild"
          "jbuild-ignore"
          ".merlin"
          "_CoqProject"
        ];
        character = {
          success_symbol = "[⊢](bold green) ";
          error_symbol = "[⊢](bold red) ";
        };
      }
      // recursiveMerge presets;
  };
}
