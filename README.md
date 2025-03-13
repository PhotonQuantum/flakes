# LightQuantum's Nix Flakes

In case I forget how to deploy flakes,

## Darwin

```bash
$ nix build ".#darwinConfigurations.$(hostname -s).system"
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
