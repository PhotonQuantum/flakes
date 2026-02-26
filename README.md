# LightQuantum's Nix Flakes

Canonical host outputs:

- `darwinConfigurations.mbp`
- `nixosConfigurations.meow`
- `nixosConfigurations.homelab`
- `nixosConfigurations.orb`
- `homeConfigurations."lightquantum@arch"`

## Darwin

```bash
$ nh darwin switch .
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

1. Set the real homelab disk ID and uplink NIC settings in `secrets/homelab.nix`:

```nix
{
  mainDiskId = "REPLACE_WITH_REAL_DISK_BY_ID";
  uplinkMacAddress = "REPLACE_WITH_REAL_UPLINK_MAC";
  uplinkName = "lan0";
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
$ colmena apply --target homelab
```

## Manual configuration

1. Setup cloudflare tunnel and add the tunnel ID and credentials to `secrets/cf`.
2. Add borg repo to `secrets/homelab.nix` and add passphrase to `secrets/homelab_borg.pass`.
3. Get forgejo action reg token from forgejo instance and add it to `secrets/homelab.nix`, then restart forgejo-runner microvm.