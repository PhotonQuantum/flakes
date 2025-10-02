# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a Nix flakes repository managing NixOS and nix-darwin configurations for multiple systems:
- **mbp**: MacBook Pro M1 (aarch64-darwin) with nix-darwin
- **meow**: Remote NixOS server (x86_64-linux)
- **orbstack**: OrbStack container environment (aarch64-linux)

## Essential Commands

### Building & Switching Configurations

**macOS (Darwin):**
```bash
# Build and switch using darwin-rebuild
nix build ".#darwinConfigurations.$(hostname -s).system"
./result/sw/bin/darwin-rebuild switch --flake .

# Or using nh (if available)
nh darwin switch .
```

**Deploy to Remote Server (meow):**
```bash
colmena apply
# or
nix run nixpkgs#colmena apply
```

**Update External Dependencies:**
```bash
nvfetcher  # Regenerates package sources in _sources/
```

**Test Nix Expressions:**
```bash
# Evaluate a specific attribute
nix eval .#darwinConfigurations.mbp.system

# Check flake outputs
nix flake show

# Check flake metadata
nix flake metadata
```

## High-Level Architecture

### Flake Structure
- **flake.nix**: Central configuration defining all system outputs and inputs
- **nvfetcher.toml**: Fetches external packages not in nixpkgs, generates overlays
- Each system directory contains its own `configuration.nix` and hardware-specific settings

### Module Organization
- **common/**: Shared configurations across all systems (shell, git, editor configs)
  - Fish shell with custom abbreviations
  - NixVim (Neovim) configuration
  - Git with delta differ
  - Starship prompt
  - Yazi file manager
- **modules/**: Custom home-manager modules extending functionality
- **secrets/**: Encrypted with git-crypt, contains SSH keys and signing keys

### Key Design Patterns
1. **Overlays**: Generated overlays in `_sources/` from nvfetcher for external packages
2. **Home Manager Integration**: User-specific configurations under each system directory
3. **Distributed Builds**: macOS offloads Linux builds to meow server via SSH
4. **Modular Configuration**: Each tool/service has its own module file for maintainability

### System-Specific Features

**mbp (macOS):**
- AeroSpace window manager configuration
- SketchyBar status bar with Lua scripts
- Phoenix.js for additional window management
- Homebrew integration for GUI apps
- Touch ID for sudo authentication
- Extensive Rust development toolchain

**meow (Server):**
- SSH on port 20422 (not default 22)
- Borg backup configuration
- Matrix (Dendrite) server
- Docker support
- Serves as remote build machine

## Development Notes

### Adding New Packages
1. If package is in nixpkgs, add to relevant system's packages list
2. For external packages, add to `nvfetcher.toml` and run `nvfetcher`
3. Overlays are automatically applied from generated sources

### Modifying Configurations
- System-level changes go in `{system}/configuration.nix`
- User-level changes go in `{system}/lightquantum.nix` (home-manager)
- Shared configurations should be added to `common/`

### Secret Management
- Repository uses git-crypt for secrets
- Never commit unencrypted secrets
- SSH and signing keys are in `secrets/` directory

### Testing Changes
- Always test locally with `darwin-rebuild build` before switching
- For remote deployment, use `colmena build` to verify before applying
- Check `nix flake check` for evaluation errors