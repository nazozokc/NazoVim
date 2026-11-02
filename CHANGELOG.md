# NazoVim Changelog

<!-- markdownlint-disable-file MD024 MD013 -->
<!-- markdownlint-configure-file { "MD024": { "siblings_only": true } } -->

## [v2.0.0](https://github.com/nazozokc/NazoVim/releases/tag/v2.0.0) (2026-10-29)

NazoVim 2.0 introduces **nazoplug**, a built-in plugin manager with lazy loading, concurrent installation, and a live progress UI. This release also adds Avante AI integration and reorganizes the repository into a monorepo.

### What's Changed

* **Built-in plugin management:** manage installation, updates, lockfile restoration, cleanup, and build hooks with `:NazoPlug`. Plugin specs support tags, pinned versions, conditions, and function-based enablement. ([#98](https://github.com/nazozokc/NazoVim/pull/98))
* **Concurrent installation and progress UI:** install plugins with bounded concurrency and dependency coordination, follow progress in a floating window, and open `:NazoPlug` without arguments to browse plugin status, branches, and commits. ([#103](https://github.com/nazozokc/NazoVim/pull/103))
* **Avante AI integration:** add an AI coding assistant with sidebar chat and editing workflows. ([#86](https://github.com/nazozokc/NazoVim/pull/86))
* **Faster startup:** improve lazy loading and cache plugin specs to reduce startup work. ([#87](https://github.com/nazozokc/NazoVim/pull/87), [#98](https://github.com/nazozokc/NazoVim/pull/98))
* **Nix launcher improvements:** link configuration from the Nix store instead of copying it on every launch, while keeping runtime lockfiles in the writable data directory. ([#88](https://github.com/nazozokc/NazoVim/pull/88))
* **Monorepo layout:** organize Neovim configuration under `apps/nvim/`, nazoplug under `apps/nazoplug/`, and Nix package definitions under `packages/nix/`. Separate nazoplug boot, spec state, and migration responsibilities. ([#94](https://github.com/nazozokc/NazoVim/pull/94), [#98](https://github.com/nazozokc/NazoVim/pull/98), [#102](https://github.com/nazozokc/NazoVim/pull/102))

### Bug Fixes

* Fix missing branch and commit information in the plugin browser, and stabilize progress rendering during asynchronous operations. ([#103](https://github.com/nazozokc/NazoVim/pull/103))
* Fix Treesitter parser incompatibility with the bundled Neovim version and replace removed Nix `nodePackages` references. ([#101](https://github.com/nazozokc/NazoVim/pull/101))
* Add Avante's missing `mega.cmdparse` dependency. ([#100](https://github.com/nazozokc/NazoVim/pull/100))
* Disable the lazy.nvim-only dashboard startup statistics section when using nazoplug. ([#99](https://github.com/nazozokc/NazoVim/pull/99))
* Correct duplicate keymaps, LSP enablement, and inconsistent plugin disabling. ([#89](https://github.com/nazozokc/NazoVim/pull/89), [#92](https://github.com/nazozokc/NazoVim/pull/92))

### Breaking Changes and Migration

* **nazoplug is now required.** The lazy.nvim fallback and `NAZOVIM_PLUGIN_MANAGER` environment export have been removed. Use `:NazoPlug` for plugin management.
* **Migration is explicit.** To reuse an existing lazy.nvim plugin data directory, run `:NazoPlug migrate`; boot-time automatic migration has been removed. The command discovers the legacy directory itself, so `opts.old_pack_dir` is no longer supported.
* **Custom nazoplug setup options have changed:** replace `setup(opts, extra)` with `setup({ spec = ..., ... })`, move `opts.performance.rtp.disabled_plugins` to `opts.disabled_plugins`, and configure the colorscheme through a plugin spec instead of `opts.install.colorscheme`.
* **Manual installations must account for the monorepo layout.** Include both `apps/nvim/` and `apps/nazoplug/` when using sparse checkout. Follow the updated [installation instructions](https://github.com/nazozokc/NazoVim/blob/v2.0.0/README.md) when adapting an existing checkout or configuration symlink.

**Full Changelog**: <https://github.com/nazozokc/NazoVim/compare/v1.2.0...v2.0.0>

---

## [v1.1.2](https://github.com/nazozokc/NazoVim/releases/tag/v1.1.2) (2026-04-02)

### What's Changed

* ci: bump actions/upload-artifact from 4 to 7 by @dependabot[bot] in #65
* ci: bump actions/checkout from 4 to 6 by @dependabot[bot] in #64
* Full Changelog: v1.1.1...v1.1.2

---

## [v1.1.0](https://github.com/nazozokc/NazoVim/releases/tag/v1.1.0) (2026-04-02)

### What's Changed

* refactor: modularize config and migrate none-ls to conform + nvim-lint by @nazozokc in <https://github.com/nazozokc/NazoVim/pull/58>
* add codex.nvim plugins
* fix: code review fixes by @nazozokc in <https://github.com/nazozokc/NazoVim/pull/59>
* fix: pin nvim-treesitter to master branch by @nazozokc in <https://github.com/nazozokc/NazoVim/pull/60>
* fix: migrate to new nvim-treesitter API by @nazozokc in <https://github.com/nazozokc/NazoVim/pull/61>

**Full Changelog**: <https://github.com/nazozokc/NazoVim/compare/v1.0.7...v1.1.0>

---

## [v1.0.7](https://github.com/nazozokc/NazoVim/releases/tag/v1.0.7) (2026-04-01)

### 🐛 Bug Fixes

* Fix Neovim 0.12.0 compatibility issues ([#52](https://github.com/nazozokc/NazoVim/pull/52))

### ♻️ Refactoring

* Fix code review issues and improve overall configuration ([#53](https://github.com/nazozokc/NazoVim/pull/53))

**Full Changelog**: <https://github.com/nazozokc/NazoVim/compare/v1.0.6...v1.0.7>

---

## [v1.0.6](https://github.com/nazozokc/NazoVim/releases/tag/v1.0.6) (2026-03-31)

### ✨ Features

* Add `neovim_12` override configuration for forward compatibility ([#50](https://github.com/nazozokc/NazoVim/pull/50))
* Integrate AI agent support ([#46](https://github.com/nazozokc/NazoVim/pull/46))

### 🐛 Bug Fixes

* Fix Neovim v0.12.0 compatibility ([#45](https://github.com/nazozokc/NazoVim/pull/45))
* Resolve CI action version issues and keymap conflicts ([#47](https://github.com/nazozokc/NazoVim/pull/47))
* Update deprecated plugin APIs and fix critical bugs ([#51](https://github.com/nazozokc/NazoVim/pull/51))

**Full Changelog**: <https://github.com/nazozokc/NazoVim/compare/v1.0.5...v1.0.6>

---

## [v1.0.5](https://github.com/nazozokc/NazoVim/releases/tag/v1.0.5) (2026-03-30)

### 🔧 CI

* Add CI workflows for Nix, Markdown, and JSON validation ([#42](https://github.com/nazozokc/NazoVim/pull/42))

**Full Changelog**: <https://github.com/nazozokc/NazoVim/compare/v1.0.2...v1.0.5>

---

## [v1.0.2](https://github.com/nazozokc/NazoVim/releases/tag/v1.0.2) (2026-03-28)

### ♻️ Refactoring

* Fix keymap conflicts and remove unused plugin ([#40](https://github.com/nazozokc/NazoVim/pull/40))

**Full Changelog**: <https://github.com/nazozokc/NazoVim/compare/v1.0.1...v1.0.2>

---

## [v1.0.1](https://github.com/nazozokc/NazoVim/releases/tag/v1.0.1) (2026-03-25)

CI dependency updates only (actions/checkout, actions/upload-artifact, actions/cache).

**Full Changelog**: <https://github.com/nazozokc/NazoVim/compare/v1.0.0...v1.0.1>

---

## [v1.0.0](https://github.com/nazozokc/NazoVim/releases/tag/v1.0.0) (2026-03-18)

First stable release of NazoVim — a personal Neovim distribution focused on CLI/TUI workflows.

### ✨ Highlights

* **Nix flake support** — run isolated without touching existing config via `nix run github:nazozokc/NazoVim`
* **Kanagawa Dragon theme** with transparent background for a unified terminal experience
* **Aggressive lazy-loading** via lazy.nvim (startup target: ~55–70ms)
* **snacks.nvim** unifies Dashboard, Picker, Zen mode, and session management
* **Full LSP** — TypeScript, Lua, Ruby, Nix, C, Java, Zig
* **AI integration** — claudecode.nvim (Claude Code) and opencode.nvim
* **DAP** — minimal JavaScript/TypeScript debug setup
* **neotest** — Jest, Vitest, and Playwright adapters included

### 📦 Installation

```sh
# Recommended (isolated, preserves existing config)
nix run github:nazozokc/NazoVim

# Clone
git clone https://github.com/nazozokc/NazoVim.git ~/.config/nvim && nvim
```

**Full Changelog**: <https://github.com/nazozokc/NazoVim/commits/v1.0.0>

---

## [v0.2.8](https://github.com/nazozokc/NazoVim/releases/tag/v0.2.8) (2026-03-18)

No notable changes.

**Full Changelog**: <https://github.com/nazozokc/NazoVim/compare/v0.2.7...v0.2.8>

---

## [v0.2.7](https://github.com/nazozokc/NazoVim/releases/tag/v0.2.7) (2026-03-18)

### 🐛 Bug Fixes

* Resolve 7 issues with clone-based distribution ([#35](https://github.com/nazozokc/NazoVim/pull/35))

**Full Changelog**: <https://github.com/nazozokc/NazoVim/compare/v0.2.6...v0.2.7>

---

## [v0.2.6](https://github.com/nazozokc/NazoVim/releases/tag/v0.2.6) (2026-03-18)

### 🐛 Bug Fixes

* Resolve 13 issues covering security, performance, maintainability, and consistency ([#34](https://github.com/nazozokc/NazoVim/pull/34))

**Full Changelog**: <https://github.com/nazozokc/NazoVim/compare/v0.2.5...v0.2.6>

---

## [v0.2.5](https://github.com/nazozokc/NazoVim/releases/tag/v0.2.5) (2026-03-18)

### 🐛 Bug Fixes

* Fix healthcheck errors ([#19](https://github.com/nazozokc/NazoVim/pull/19))

### ♻️ Refactoring

* Update and reorganize plugin configuration ([#20](https://github.com/nazozokc/NazoVim/pull/20))

**Full Changelog**: <https://github.com/nazozokc/NazoVim/compare/v0.2.4...v0.2.5>

---

## [v0.2.4](https://github.com/nazozokc/NazoVim/releases/tag/v0.2.4) (2026-03-18)

No notable changes.

**Full Changelog**: <https://github.com/nazozokc/NazoVim/compare/v0.2.3...v0.2.4>

---

## [v0.2.3](https://github.com/nazozokc/NazoVim/releases/tag/v0.2.3) (2026-03-18)

No notable changes.

**Full Changelog**: <https://github.com/nazozokc/NazoVim/compare/v0.2.0...v0.2.3>

---

## [v0.2.0](https://github.com/nazozokc/NazoVim/releases/tag/v0.2.0) (2026-03-18)

### ✨ Features

* Rewrite README with improved structure and English documentation ([#5](https://github.com/nazozokc/NazoVim/pull/5))
* Improve README with maintenance guide and safety warnings ([#6](https://github.com/nazozokc/NazoVim/pull/6))

### 🐛 Bug Fixes

* Resolve CI and configuration issues ([#7](https://github.com/nazozokc/NazoVim/pull/7))

### ♻️ Refactoring

* Reorganize plugins into category subdirectories ([#8](https://github.com/nazozokc/NazoVim/pull/8))

**Full Changelog**: <https://github.com/nazozokc/NazoVim/commits/V0.2.0>

---

## [v0.1.0](https://github.com/nazozokc/NazoVim/releases/tag/v0.1.0) (2026-03-18)

### ✨ Features

* Integrate AI agent support ([#16](https://github.com/nazozokc/NazoVim/pull/16))

### 🐛 Bug Fixes

* Fix template directory names and remove invalid variables option ([#11](https://github.com/nazozokc/NazoVim/pull/11))

**Full Changelog**: <https://github.com/nazozokc/NazoVim/commits/v0.1.0>
