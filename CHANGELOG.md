# NazoVim Changelog

<!-- markdownlint-disable-file MD024 MD013 -->
<!-- markdownlint-configure-file { "MD024": { "siblings_only": true } } -->

## [v1.0.7](https://github.com/NazoVim-org/NazoVim/releases/tag/v1.0.7) (2026-04-01)

### 🐛 Bug Fixes

- Fix Neovim 0.12.0 compatibility issues ([#52](https://github.com/NazoVim-org/NazoVim/pull/52))

### ♻️ Refactoring

- Fix code review issues and improve overall configuration ([#53](https://github.com/NazoVim-org/NazoVim/pull/53))

**Full Changelog**: <https://github.com/NazoVim-org/NazoVim/compare/v1.0.6...v1.0.7>

---

## [v1.0.6](https://github.com/NazoVim-org/NazoVim/releases/tag/v1.0.6) (2026-03-31)

### ✨ Features

- Add `neovim_12` override configuration for forward compatibility ([#50](https://github.com/NazoVim-org/NazoVim/pull/50))
- Integrate AI agent support ([#46](https://github.com/NazoVim-org/NazoVim/pull/46))

### 🐛 Bug Fixes

- Fix Neovim v0.12.0 compatibility ([#45](https://github.com/NazoVim-org/NazoVim/pull/45))
- Resolve CI action version issues and keymap conflicts ([#47](https://github.com/NazoVim-org/NazoVim/pull/47))
- Update deprecated plugin APIs and fix critical bugs ([#51](https://github.com/NazoVim-org/NazoVim/pull/51))

**Full Changelog**: <https://github.com/NazoVim-org/NazoVim/compare/v1.0.5...v1.0.6>

---

## [v1.0.5](https://github.com/NazoVim-org/NazoVim/releases/tag/v1.0.5) (2026-03-30)

### 🔧 CI

- Add CI workflows for Nix, Markdown, and JSON validation ([#42](https://github.com/NazoVim-org/NazoVim/pull/42))

**Full Changelog**: <https://github.com/NazoVim-org/NazoVim/compare/v1.0.2...v1.0.5>

---

## [v1.0.2](https://github.com/NazoVim-org/NazoVim/releases/tag/v1.0.2) (2026-03-28)

### ♻️ Refactoring

- Fix keymap conflicts and remove unused plugin ([#40](https://github.com/NazoVim-org/NazoVim/pull/40))

**Full Changelog**: <https://github.com/NazoVim-org/NazoVim/compare/v1.0.1...v1.0.2>

---

## [v1.0.1](https://github.com/NazoVim-org/NazoVim/releases/tag/v1.0.1) (2026-03-25)

CI dependency updates only (actions/checkout, actions/upload-artifact, actions/cache).

**Full Changelog**: <https://github.com/NazoVim-org/NazoVim/compare/v1.0.0...v1.0.1>

---

## [v1.0.0](https://github.com/NazoVim-org/NazoVim/releases/tag/v1.0.0) (2026-03-18)

First stable release of NazoVim — a personal Neovim distribution focused on CLI/TUI workflows.

### ✨ Highlights

- **Nix flake support** — run isolated without touching existing config via `nix run github:NazoVim-org/NazoVim`
- **Kanagawa Dragon theme** with transparent background for a unified terminal experience
- **Aggressive lazy-loading** via lazy.nvim (startup target: ~55–70ms)
- **snacks.nvim** unifies Dashboard, Picker, Zen mode, and session management
- **Full LSP** — TypeScript, Lua, Ruby, Nix, C, Java, Zig
- **AI integration** — claudecode.nvim (Claude Code) and opencode.nvim
- **DAP** — minimal JavaScript/TypeScript debug setup
- **neotest** — Jest, Vitest, and Playwright adapters included

### 📦 Installation

```sh
# Recommended (isolated, preserves existing config)
nix run github:NazoVim-org/NazoVim

# Clone
git clone https://github.com/NazoVim-org/NazoVim.git ~/.config/nvim && nvim
```

**Full Changelog**: <https://github.com/NazoVim-org/NazoVim/commits/v1.0.0>

---

## [v0.2.8](https://github.com/NazoVim-org/NazoVim/releases/tag/v0.2.8) (2026-03-18)

No notable changes.

**Full Changelog**: <https://github.com/NazoVim-org/NazoVim/compare/v0.2.7...v0.2.8>

---

## [v0.2.7](https://github.com/NazoVim-org/NazoVim/releases/tag/v0.2.7) (2026-03-18)

### 🐛 Bug Fixes

- Resolve 7 issues with clone-based distribution ([#35](https://github.com/NazoVim-org/NazoVim/pull/35))

**Full Changelog**: <https://github.com/NazoVim-org/NazoVim/compare/v0.2.6...v0.2.7>

---

## [v0.2.6](https://github.com/NazoVim-org/NazoVim/releases/tag/v0.2.6) (2026-03-18)

### 🐛 Bug Fixes

- Resolve 13 issues covering security, performance, maintainability, and consistency ([#34](https://github.com/NazoVim-org/NazoVim/pull/34))

**Full Changelog**: <https://github.com/NazoVim-org/NazoVim/compare/v0.2.5...v0.2.6>

---

## [v0.2.5](https://github.com/NazoVim-org/NazoVim/releases/tag/v0.2.5) (2026-03-18)

### 🐛 Bug Fixes

- Fix healthcheck errors ([#19](https://github.com/NazoVim-org/NazoVim/pull/19))

### ♻️ Refactoring

- Update and reorganize plugin configuration ([#20](https://github.com/NazoVim-org/NazoVim/pull/20))

**Full Changelog**: <https://github.com/NazoVim-org/NazoVim/compare/v0.2.4...v0.2.5>

---

## [v0.2.4](https://github.com/NazoVim-org/NazoVim/releases/tag/v0.2.4) (2026-03-18)

No notable changes.

**Full Changelog**: <https://github.com/NazoVim-org/NazoVim/compare/v0.2.3...v0.2.4>

---

## [v0.2.3](https://github.com/NazoVim-org/NazoVim/releases/tag/v0.2.3) (2026-03-18)

No notable changes.

**Full Changelog**: <https://github.com/NazoVim-org/NazoVim/compare/v0.2.0...v0.2.3>

---

## [v0.2.0](https://github.com/NazoVim-org/NazoVim/releases/tag/v0.2.0) (2026-03-18)

### ✨ Features

- Rewrite README with improved structure and English documentation ([#5](https://github.com/NazoVim-org/NazoVim/pull/5))
- Improve README with maintenance guide and safety warnings ([#6](https://github.com/NazoVim-org/NazoVim/pull/6))

### 🐛 Bug Fixes

- Resolve CI and configuration issues ([#7](https://github.com/NazoVim-org/NazoVim/pull/7))

### ♻️ Refactoring

- Reorganize plugins into category subdirectories ([#8](https://github.com/NazoVim-org/NazoVim/pull/8))

**Full Changelog**: <https://github.com/NazoVim-org/NazoVim/commits/V0.2.0>

---

## [v0.1.0](https://github.com/NazoVim-org/NazoVim/releases/tag/v0.1.0) (2026-03-18)

### ✨ Features

- Integrate AI agent support ([#16](https://github.com/NazoVim-org/NazoVim/pull/16))

### 🐛 Bug Fixes

- Fix template directory names and remove invalid variables option ([#11](https://github.com/NazoVim-org/NazoVim/pull/11))

**Full Changelog**: <https://github.com/NazoVim-org/NazoVim/commits/v0.1.0>
