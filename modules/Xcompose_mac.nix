{ config, lib, pkgs, pyproject-nix, ... }:

with lib;

{
  options = {
    home.Xcompose = mkOption
      {
        type = with types; nullOr (attrsOf str);
        default = null;
      };
  };
  config =
    let
      gen-compose = (pkgs.callPackage ../gen-compose/default.nix { inherit pkgs pyproject-nix; }).package;
      checkPrefixConflict = attrs:
        let
          getPrefixConflicts = attrs:
            let
              keys = builtins.attrNames attrs;
              isPrefix = prefix: str: builtins.substring 0 (builtins.stringLength prefix) str == prefix;
            in
            lib.filter
              ({ fst, snd }:
                (isPrefix fst snd) && fst != snd
              )
              (lib.mapCartesianProduct ({ x, y }: { fst = x; snd = y; }) { x = keys; y = keys; });
          conflicts = getPrefixConflicts attrs;
        in
        lib.asserts.assertMsg (builtins.length conflicts == 0) (
          "Error: Found keys with prefix conflicts: " + builtins.concatStringsSep ", " (
            lib.map ({ fst, snd }: "`" + snd + "` shadowed by `" + fst + "`") conflicts
          )
        );
      Xcompose = config.home.Xcompose;
      XcomposeFile = pkgs.writeTextFile {
        name = "Xcompose.yaml";
        text = builtins.toJSON (if checkPrefixConflict Xcompose then Xcompose else { });
      };
      bindingsFile = pkgs.runCommand "keyBindings.dict" { } ''
        ${gen-compose}/bin/gen-compose ${XcomposeFile} > $out
      '';
    in
    {
      home.file."Library/KeyBindings/DefaultKeyBinding.dict" = mkIf (Xcompose != null) {
        source = bindingsFile;
      };
    };
}
