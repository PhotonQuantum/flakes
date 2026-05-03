{ inputs, ... }:
{
  perSystem =
    {
      inputs',
      lib,
      system,
      ...
    }:
    let
      repoPackages =
        pkgs':
        import ../../pkgs {
          inherit inputs';
          pkgs = pkgs' // {
            inherit lib;
          };
        };

      generatedOverlay = final: _prev: {
        generated = (import ../../_sources/generated.nix) {
          inherit (final)
            fetchurl
            fetchgit
            fetchFromGitHub
            dockerTools
            ;
        };
      };

      aerospaceMarks = inputs'.aerospace-mark.packages.default or null;
      canonicalPkgs = import inputs.nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          allowUnfreePredicate = _: true;
          permittedInsecurePackages = [
            "openssl-1.1.1u"
          ];
        };
        overlays = [
          generatedOverlay
          inputs.tex-fmt.overlays.default
          inputs.colmena.overlays.default
          (_final: prev: repoPackages prev)
          (_final: prev: {
            sbarlua = prev.callPackage ../../hosts/mbp/sketchybar/sbarlua.nix { };
          })
        ]
        ++ lib.optionals (aerospaceMarks != null) [
          (_final: _prev: {
            aerospace-marks = aerospaceMarks;
          })
        ];
      };
    in
    {
      _module.args.pkgs = canonicalPkgs;

      packages = repoPackages canonicalPkgs;
    };
}
