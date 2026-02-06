{ writers, python3Packages }:
writers.writePython3Bin "gen-compose" {
  libraries = with python3Packages; [
    click
    pyyaml
  ];
  flakeIgnore = [
    "E501"
    "E731"
  ];
} (builtins.readFile ./gen_compose.py)
