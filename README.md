# LightQuantum's Nix Flakes

Canonical host outputs:

- `darwinConfigurations.mbp`
- `nixosConfigurations.meow`
- `nixosConfigurations.orb`
- `homeConfigurations."lightquantum@arch"`

## Darwin

```bash
$ nix build .#darwinConfigurations.mbp.system
$ ./result/sw/bin/darwin-rebuild switch --flake .
```

## Tools

- `bin/nix-build-plan-classify <installable>`: dry-run a build and classify derivations as `real-ish`, `wrapper-ish`, or `inspect`.
- `bin/hydra-latest-nixpkgs-rev <pkg...> --system <system>`: query Hydra for the newest nixpkgs revision where the given jobs are present.
- `bin/pick-nixpkgs-rev [installable]`: start from the latest `nixpkgs-unstable` revision, dry-run the target, walk backward with Hydra until the missing package set stabilizes, and optionally apply the resolved revision to `flake.lock`.

Examples:

```bash
$ ./bin/nix-build-plan-classify .#darwinConfigurations.mbp.config.system.build.toplevel
$ ./bin/hydra-latest-nixpkgs-rev hello --system x86_64-linux
$ ./bin/pick-nixpkgs-rev .#darwinConfigurations.mbp.config.system.build.toplevel
```

## Deploy to remote NixOS machine

```bash
$ colmena apply
```

or,

```bash
$ nix run nixpkgs#colmena apply
```

And later I just need to run

```bash
$ nh darwin switch .
```

Legacy aliases are still available during migration:

- `darwinConfigurations.lightquantum-mbp`
- `nixosConfigurations.lightquantum-meow`
- `nixosConfigurations.orbstack-nixos`
- `homeConfigurations."lightquantum@lightquantum-arch"`
