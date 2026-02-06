{ writers, python3Packages }:
writers.writePython3Bin "validate-cam-imports" {
  libraries = with python3Packages; [
    click
    blake3
    tqdm
  ];
  flakeIgnore = [ "E501" ];
} (builtins.readFile ./validate_camera_imports.py)
