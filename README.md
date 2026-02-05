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
