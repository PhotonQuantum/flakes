{ pkgs }:
[
  {
    name = "hermes-lcm";
    version = pkgs.generated.hermes_lcm.version;
    src = pkgs.generated.hermes_lcm.src;
  }
]
