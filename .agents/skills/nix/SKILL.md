---
name: nix
description: When managing NazoVim's Nix flake, flake.lock, or devShell configuration
---

# NazoVim Nix Management Skill

## When to Use

- When updating flake.nix or flake.lock
- When changing devShell dependencies
- When modifying the Nix build configuration

## Key Files

| File        | Purpose                                      |
| ----------- | -------------------------------------------- |
| `flake.nix` | Main flake (version, packages, devShell)     |
| `flake.lock`| Pinned input versions                        |

## Common Operations

### Update all flake inputs

```bash
nix flake update
```

### Update a specific input

```bash
nix flake lock --update-input nixpkgs
```

### Verify flake

```bash
nix flake check
nix build .#default
nix build .#config
nix develop --command true
```

## Flake Structure

- `neovim_12` — Overlay pinning Neovim to v0.12.0
- `nvimConfig` — Derivation copying repo to Nix store (excludes `.git`)
- `nvim-nazozokc` — Wrapped neovim with `NVIM_APPNAME` isolation
- `devShells.default` — Dev environment with LSP, formatters, runtimes

## Version Field

The `version` field in `flake.nix` is updated automatically by
`release.yml` during releases. Do not update it manually.

## Notes

- Systems: `x86_64-linux`, `aarch64-linux`, `aarch64-darwin`
- `nix run github:nazozokc/NazoVim` launches isolated Neovim
- `nix develop` sets `NVIM_APPNAME=nvim-nazozokc` automatically
