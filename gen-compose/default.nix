{ pkgs, pyproject-nix, ... }:
let
  project = pyproject-nix.lib.project.loadPyproject {
    # Read & unmarshal pyproject.toml relative to this project root.
    # projectRoot is also used to set `src` for renderers such as buildPythonPackage.
    projectRoot = ./.;
  };

  python = pkgs.python3;

in
{
  package =
    let
      # Returns an attribute set that can be passed to `buildPythonPackage`.
      attrs = project.renderers.buildPythonPackage { inherit python; };
    in
    # Pass attributes to buildPythonPackage.
    # Here is a good spot to add on any missing or custom attributes.
    python.pkgs.buildPythonPackage (attrs);
}
