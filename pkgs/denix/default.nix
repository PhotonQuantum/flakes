{ writers, python3Packages }:
writers.writePython3Bin "denix" {
  libraries = [ python3Packages.click ];
  flakeIgnore = [
    "E501"
    "E265"
  ];
} (builtins.readFile ./denix.py)
