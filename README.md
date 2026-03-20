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

## Provision homelab with nixos-anywhere + disko

1. Set the real homelab disk ID and uplink NIC settings in `secrets/homelab.nix`:

```nix
{
  mainDiskId = "REPLACE_WITH_REAL_DISK_BY_ID";
  uplinkMacAddress = "REPLACE_WITH_REAL_UPLINK_MAC";
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
3. Set `lanSubnet` in `secrets/homelab.nix` to the local LAN CIDR.
4. Get forgejo action reg token from forgejo instance and add it to `secrets/homelab.nix`, then restart forgejo-runner microvm.
5. Put tailscale preauth key to `secrets/tailscale_key`.
6. Set homelab tailscale ip to 100.101.100.100 for dns to work.
7. Configure syncthing.
