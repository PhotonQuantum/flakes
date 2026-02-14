# LightQuantum's Nix Flakes

Canonical host outputs:

- `darwinConfigurations.mbp`
- `nixosConfigurations.meow`
- `nixosConfigurations.homelab`
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

## Provision homelab with nixos-anywhere + disko

1. Set the real target disk ID in `secrets/homelab-disk-id.nix`:

```nix
{
  mainDiskId = "REPLACE_WITH_REAL_DISK_BY_ID";
}
```

`hosts/homelab/disko.nix` will resolve it as `/dev/disk/by-id/${mainDiskId}`.
2. Optional dry run with a VM:

```bash
$ nix run github:nix-community/nixos-anywhere -- --flake .#homelab --vm-test
```

3. Provision the real machine and generate `hardware-configuration.nix`:

```bash
$ nix run github:nix-community/nixos-anywhere -- --flake .#homelab --generate-hardware-config nixos-generate-config ./hosts/homelab/hardware-configuration.nix root@<target-ip-or-host>
```

4. After install, rebuild remotely as needed:

```bash
$ nixos-rebuild switch --flake .#homelab --target-host lightquantum@<target-ip-or-host> --use-remote-sudo
```

Legacy aliases are still available during migration:

- `darwinConfigurations.lightquantum-mbp`
- `nixosConfigurations.lightquantum-meow`
- `nixosConfigurations.lightquantum-homelab`
- `nixosConfigurations.orbstack-nixos`
- `homeConfigurations."lightquantum@lightquantum-arch"`
