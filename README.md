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
$ colmena apply --on homelab
```

If using determinate nix,

```bash
$ colmena upload-keys --on homelab --nix-option lazy-trees false
$ colmena apply --on homelab --no-keys
```

## Manual configuration

1. Setup cloudflare tunnel and add the tunnel ID and credentials to `secrets/cf`.
2. Add borg repo to `secrets/homelab.nix` and add passphrase to `secrets/homelab_borg.pass`.
3. Get forgejo action reg token from forgejo instance and add it to `secrets/homelab.nix`, then restart forgejo-runner microvm.
4. Put the homelab host Tailscale auth key in `secrets/tailscale_key`.
5. Set homelab provisioning settings in `secrets/homelab.nix`:

```nix
{
  tailscaleAuthKeyDir = "/absolute/path/to/secrets/tailscale-authkeys";
  tailscaleDns = {
    domain = "lqhome.me";
    resolverTag = "tag:dns";
  };
  beszel.secretDir = "/absolute/path/to/secrets/beszel";
}
```

> Note: when deploying the module from another machine, one must update `tailscaleAuthKeyDir` and `beszel.secretDir` accordingly.

6. Generate API credentials at <https://login.tailscale.com/admin/settings/keys> and export them locally:

```bash
$ export TS_TAILNET='...'
$ export TS_API_KEY='...'
```

7. Reconcile Tailscale policy, MicroVM auth keys, homelab keys, and the host:

```bash
$ nix run .#tailscale-deploy-policy
$ nix run .#tailscale-provision-auth-keys
$ nix run .#beszel-provision
$ colmena upload-keys --on homelab --nix-option lazy-trees false
$ colmena apply --on homelab --no-keys
```

8. After the `coredns` MicroVM is online, configure split DNS for the homelab domain:

```bash
$ nix run .#tailscale-deploy-dns
```

9. Configure syncthing.
