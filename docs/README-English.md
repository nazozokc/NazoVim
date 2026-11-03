# NazoVim

```text
█   █  ███  █████  ███  █   █ ███ █   █
██  █ █   █     █ █   █ █   █  █  ██ ██
█ █ █ █   █    █  █   █ █   █  █  █ █ █
█  ██ █████   █   █   █ █   █  █  █   █
█   █ █   █  █    █   █  █ █   █  █   █
█   █ █   █ █     █   █  █ █   █  █   █
█   █ █   █ █████  ███    █   ███ █   █
```

**A personal Neovim distribution by [nazozokc](https://github.com/nazozokc)**

[![CI](https://github.com/nazozokc/NazoVim/actions/workflows/nvim.yml/badge.svg)](https://github.com/nazozokc/NazoVim/actions/workflows/nvim.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
![Neovim](https://img.shields.io/badge/Neovim-0.10%2B-blueviolet?logo=neovim)
![Nix](https://img.shields.io/badge/Nix-flake-blue?logo=nixos)

> **Note:** The CI pipeline (`nvim.yml`) runs in a Nix environment and does
> not test the plain `clone` installation path. If you install without Nix,
> please verify startup manually with `nvim --headless +q`.

---

## ✨ About

<!-- markdownlint-disable MD013 -->
**nazovim** is a personal Neovim distribution tailored for CLI/TUI-centric workflows.
Built on an original transparent dark palette and aggressive lazy-loading via the in-house `nazoplug` manager, it comes with everything needed for TypeScript, Lua, Nix, Ruby, and more.

> Distributed as a Nix flake — run it instantly in an isolated environment with a single `nix run` command.
<!-- markdownlint-enable MD013 -->

---

## 🖼️ Screenshots

> _Coming soon_

---

## 🚀 Features

<!-- markdownlint-disable MD013 -->
- **⚡ Fast startup** — Aggressive lazy-loading with nazoplug. Anything that can wait is deferred to `VeryLazy`
- **🔧 Full LSP** — Multi-language support: TypeScript / Lua / Ruby / Nix / C / Java / Zig and more. Dual setup with mason + manual (nixd)
- **🎨 NazoVim theme** — Original blue-green dark palette with a transparent background
- **🧠 AI integration** — Supports both Claude Code (`claudecode.nvim`) and opencode (`opencode.nvim`)
- **🌊 snacks.nvim** — Dashboard and Zen mode
- **🐛 DAP** — Minimal debug environment for JavaScript / TypeScript
- **📦 Nix-ready** — Isolated launch via `nix run` / LSP-equipped devShell via `nix develop`
- **🧪 Testing** — NazoVim built-in runner using project Jest / Vitest / Playwright CLIs
- **🔍 Fuzzy finding** — NazoVim's built-in picker for files, buffers, recent files, and search results
- **📝 Treesitter textobjects** — Custom syntax-node selection, movement, and argument swapping
<!-- markdownlint-enable MD013 -->

---

## 📋 Requirements

| Required | Version |
| -------- | ------- |
| Neovim | 0.10+ |
| Git | any |
| [Nerd Font](https://www.nerdfonts.com/) | Required for icons |

| Recommended | Purpose |
| ----------- | ------- |
| Nix (with flakes) | Isolated launch via `nix run` / `nix develop` |
| Node.js | TypeScript LSP / prettier |
| NazoVim built-in | Floating LazyGit terminal (`lazygit.lua`, requires external `lazygit`) |
| yazi | File manager integration |
| ripgrep | Grep search |
| fd | File search |

---

## 📦 Installation

### Option 1: `nix run` (try it without touching your config)

```bash
nix run github:nazozokc/NazoVim
```

<!-- markdownlint-disable MD013 -->
The configuration is deployed in isolation under `~/.config/nvim-nazozokc`, leaving your existing Neovim setup untouched.
<!-- markdownlint-enable MD013 -->

### Option 2: Clone (no Nix required)

<!-- markdownlint-disable MD013 -->
> **Warning**: This will overwrite your existing Neovim configuration. A backup is recommended.
<!-- markdownlint-enable MD013 -->

```bash
# Sparse checkout — downloads apps/nvim/ and apps/nazoplug/
git clone --depth 1 --filter=blob:none --sparse \
  https://github.com/nazozokc/NazoVim.git ~/.config/nvim
cd ~/.config/nvim
git sparse-checkout set apps/nvim apps/nazoplug
mv apps/nvim/* .
mkdir -p lua
cp -r apps/nazoplug/lua/nazoplug lua/
rm -rf apps
nvim
```

After the first launch, run `:NazoPlug install` to install missing plugins.
If you have an existing lazy.nvim setup,
run `:NazoPlug migrate` to reuse its data directory.

> For development, clone the full repository instead:
> `git clone https://github.com/nazozokc/NazoVim.git`

---

## 🗂️ Directory Structure

```text
.
├── apps/
│   ├── nvim/                 # 🎯 Neovim configuration (entry point)
│   │   ├── init.lua          # nazoplug bootstrap (lazy.nvim fallback)
│   │   ├── nazoplug-lock.json # Plugin version lock
│   │   └── lua/
│   │       ├── config/       # options / keymaps / autocmds
│   │       ├── plugins.lua   # Plugin category imports
│   │       └── plugins/      # Plugin configs (one file per plugin)
│   └── nazoplug/             # In-house plugin manager
│       ├── lua/nazoplug/     # loader / installer / lock / git
│       └── tests/            # headless tests
├── packages/
│   └── nix/                  # Nix modules
├── template/                 # File templates
│   ├── js/
│   ├── ts/
│   ├── lua/
│   ├── md/
│   └── project/
├── flake.nix                 # Nix flake (nix run / nix develop)
├── docs/
└── .github/                  # CI workflows / issue templates
```

---

## 🔌 Plugins

### LSP / Completion

| Plugin | Purpose |
| ------ | ------ |
| nvim-lspconfig + mason | LSP management |
| typescript-tools.nvim | TypeScript-specific LSP (performance-tuned) |
| nvim-cmp | Completion engine |
| NazoVim built-in | Command-line completion (`cmdline_completion.lua`) |
| NazoVim built-in | Independent snippet expansion and placeholder navigation (`snippets.lua`, VSCode JSON subset) |
| NazoVim built-in | Tree-sitter node selection expansion and contraction (`incremental_selection.lua`) |
| NazoVim built-in | Neovim code actions (`lsp_actions.lua`) |
| NazoVim built-in | LSP code action diff preview (`action_preview.lua`) |
| NazoVim built-in | LSP refactoring actions (`refactor.lua`) |
| NazoVim built-in | External formatters (`format.lua`) |
| NazoVim built-in | External lint diagnostics (ESLint, RuboCop, Luacheck, Nix, markdownlint) |
| NazoVim built-in | Task runner and history (`tasks.lua`) |
| NazoVim built-in | LSP progress display |
| NazoVim built-in | Inline diagnostics |
| lazydev.nvim | Enhanced Lua/Neovim API completion and type checking |

### Fuzzy Finder / Navigation

| Plugin | Purpose |
| ------ | ------ |
| snacks.nvim | Dashboard / Zen |
| NazoVim built-in | File, buffer, recent-item, and text-search picker (`picker.lua`) |
| telescope.nvim | Fuzzy finder (secondary) |
| NazoVim built-in | Buffer-based file browser (`file_browser.lua`) |
| neo-tree.nvim | Tree-style file explorer |
| yazi.nvim | yazi file manager integration |
| NazoVim built-in | Winbar / syntax breadcrumbs (`breadcrumb.lua`) |
| NazoVim built-in | Translation command (`translate.lua`, uses Translate Shell) |
| NazoVim built-in | package.json dependency versions and package manager actions (`package_info.lua`) |
| NazoVim built-in | Visible-range `<CR>` and Treesitter-node `<S-CR>` jumps (`jump.lua`) |
| NazoVim built-in | Symbol outline (`outline.lua`) |
| project.nvim | Automatic project root detection |

### UI / Appearance

| Plugin | Purpose |
| ------ | ------ |
| NazoVim built-in | Original color scheme (blue-green dark palette + transparent background, `colorscheme.lua`) |
| NazoVim built-in | Status line |
| NazoVim built-in | Buffer tabs with click navigation |
| NazoVim built-in | Indent guides / current block highlight |
| NazoVim built-in | Command line popup, notifications, and message history (`cmdline_ui.lua` / `notifications.lua`) |
| NazoVim built-in | Scrollbar |
| Built into NazoVim | Mode-based line number colors |
| NazoVim built-in | Highlight symbol under cursor |
| Built into NazoVim | Floating filename |
| NazoVim built-in | Highlight TODO/FIXME and similar |
| NazoVim built-in | Rich Markdown / Avante rendering (`markdown_render.lua`) |
| NazoVim built-in | Inline color code preview |

### Git (Plugins)

| Plugin | Purpose |
| ------ | ------ |
| NazoVim built-in | Git change signs, hunk navigation and preview, line blame (`git_signs.lua`) |
| NazoVim built-in | Git change list, history, and conflict selection (`git_review.lua`) |
| NazoVim built-in | Floating LazyGit terminal (`lazygit.lua`) |
| vim-fugitive | Git operations |
| NazoVim built-in | GitHub issue / PR lists, details, creation, title/body editing, comments, and close/reopen (`github.lua`, uses `gh` CLI) |
| NazoVim built-in | GitHub notifications and issue / PR search (`github.lua`); discussion create/edit/delete/reply, comment management, poll voting, accepted answers, upvotes, reactions, categories, subscriptions, close/reopen (`github_discussions.lua`) |
| NazoVim built-in | Issue / PR labels, assignees, milestones, project membership, reactions, and PR reviewer requests (`github_metadata.lua`) |
| NazoVim built-in | GitHub issue pinning and notification subscriptions (`github_issue_extras.lua`) |
| NazoVim built-in | PR checks, merge, checkout, ready/draft, and branch updates (`github_pr_actions.lua`) |
| NazoVim built-in | Pull request diff, inline comments, thread replies/resolution, and overall reviews (`github_review.lua`) |
| octo.nvim | Remaining GitHub operations such as project board workflows and PR commits/runs/changes |

### Editor

| Plugin | Purpose |
| ------ | ------ |
| nvim-treesitter | Syntax highlighting / indentation |
| NazoVim built-in | Tree-sitter node selection expansion and contraction (`incremental_selection.lua`) |
| NazoVim built-in | Function / class / conditional / loop / block / argument text objects (`textobjects.lua`) |
| NazoVim built-in | `motion.lua`: multi-line f/F/t/T and `;` / `,` repeat |
| NazoVim built-in | Automatic bracket / quote closing (`pairs.lua`) |
| NazoVim built-in | Surround (`sa` / `sd` / `sr`) |
| NazoVim built-in | Repeat custom edits with `.` (`repeat_action.lua`) |
| NazoVim built-in | CamelCase / snake_case-aware `w` / `e` / `b` / `ge` |
| NazoVim built-in | HTML/CSS abbreviation expansion (`abbreviations.lua`, `<C-e>,`) |
| NazoVim built-in | Extended `<C-a>/<C-x>` increment |
| NazoVim built-in | Keymap help (`<leader>?`) |
| NazoVim built-in | Mark signs and `:Marks` list |
| NazoVim built-in | Prose spell checking (`:SpellToggle`) |
| NazoVim built-in | Treesitter folding (`zR` / `zM`) |
| NazoVim built-in | Register-based substitution (`substitute.lua`) |
| Built into NazoVim | Floating terminal (`:ToggleTerm`) |
| NazoVim built-in | Send `.http` requests and display responses (`http_client.lua`, requires `curl`) |
| NazoVim built-in | OpenAPI / Swagger preview (`swagger_preview.lua`, uses `swagger-ui-watcher`) |
| NazoVim built-in | Session save and restore (`session.lua`) |

### AI Integration

| Plugin | Purpose |
| ------ | ------ |
| claudecode.nvim | Claude Code integration |
| opencode.nvim | opencode integration |
| CopilotChat.nvim | GitHub Copilot Chat |
| copilot.lua | GitHub Copilot completion |

### Debug / Test

| Plugin | Purpose |
| ------ | ------ |
| nvim-dap | DAP debugger backend |
| NazoVim built-in | DAP information panel (`dap_ui.lua`: expandable scopes, frame selection, watches) |
| nvim-dap-vscode-js | JS/TS debug adapter |
| NazoVim built-in | Test execution and latest output (`test_runner.lua`) |
| NazoVim built-in | LCOV coverage display (`coverage.lua`) |
| NazoVim built-in | DAP variable values and exception stop reasons (`dap_virtual_text.lua`) |
| NazoVim built-in | Original procedural terminal animation (`animation.lua`) |

---

## ⌨️ Keymaps

`<Leader>` = `Space`

### General

| Key | Action |
| ---- | ----- |
| `<Leader><Leader>` | File search (snacks Picker) |
| `<Leader>/` | Live Grep |
| `<Leader>b` | Buffer list |
| `<Leader>r` | Recent files |
| `<Leader>h` | Clear search highlight |
| `<Leader>z` | Zen mode |
| `<Leader>m` | File browser |
| `<Leader>n` | Neo-tree |
| `<Leader>t` | Floating terminal |
| `<Leader>f` | Format |

### LSP

| Key | Action |
| ---- | ----- |
| `K` | Hover |
| `<Leader>ls` | Signature help |
| `gd` | Go to definition |
| `ga` | Code action (Lspsaga) |
| `<Leader>ca` | Code action (preview) |
| `<Leader>gd` | Go to definition |
| `<Leader>gr` | References |
| `<Leader>oi` | Organize imports (TS) |
| `<Leader>ru` | Remove unused (TS) |

### Treesitter Textobjects

| Key | Action |
| ---- | ----- |
| `af` / `if` | outer / inner function |
| `ac` / `ic` | outer / inner class |
| `aa` / `ia` | outer / inner argument |
| `ai` / `ii` | outer / inner conditional |
| `al` / `il` | outer / inner loop |
| `ab` / `ib` | outer / inner block |
| `]f` / `[f` | Jump to next/prev function |
| `]c` / `[c` | Jump to next/prev class |
| `]a` / `[a` | Jump to next/prev argument |
| `<Leader>sn` | Swap with next argument |
| `<Leader>sp` | Swap with previous argument |

### Git (Keymaps)

| Key | Action |
| ---- | ----- |
| `<Leader>gd` | Select a changed file to review |
| `<Leader>gh` | File history |
| `<Leader>gH` | Branch history |
| `<Leader>gc` | Close Git review view |
| `<Leader>gp` | Hunk preview |
| `<Leader>gt` | Blame toggle |
| `<Leader>gg` | Open LazyGit |
| `<Leader>gi` | List issues; press `e` to edit, `c` to comment, or `x` to close/reopen in details |
| `<Leader>op` | List PRs; press `e` to edit, `c` to comment, or `x` to close/reopen in details |
| `<Leader>on` | List GitHub notifications |
| `<Leader>os` | Search GitHub issues and pull requests |
| `<Leader>od` | List GitHub Discussions; detail view supports editing, replies, comments, poll votes, reactions, subscription, and state changes |
| `<Leader>oD` | Create a GitHub Discussion |
| `<Leader>gI` | Open the GitHub issue creation form; first line is the title, `<C-s>` submits |
| `<Leader>oP` | Open the GitHub pull request creation form; first line is the title, `<C-s>` submits |
| `<Leader>oR` | Choose a pull request; use `c` on a diff line or Visual range for comments, `t` for threads; thread views use `r` to reply and `x` to resolve/reopen |
| `<Leader>om` | Manage issue / PR labels, assignees, and reactions |
| `<Leader>oA` | PR checks, merge, checkout, ready/draft, and branch updates |
| `<Leader>od` | List discussions; detail keys: `c` reply, `e` edit, `a` answer, `u` upvote, `x` close/reopen |
| `<Leader>oD` | Create a discussion |

### Session

| Key | Action |
| ---- | ----- |
| `<Leader>qs` | Restore session |
| `<Leader>qS` | Select session |
| `<Leader>ql` | Restore last session |
| `<Leader>qd` | Stop saving session |

### AI

| Key | Action |
| ---- | ----- |
| `<Leader>ac` | Claude Code toggle |
| `<Leader>af` | Claude Code focus |
| `<Leader>ab` | Add current buffer |
| `<C-a>` | opencode ask |
| `<C-x>` | opencode select action |
| `<C-.>` | opencode toggle |

### DAP

| Key | Action |
| ---- | ----- |
| `<F5>` | Run / Continue |
| `<F10>` | Step over |
| `<F11>` | Step into |
| `<F12>` | Step out |
| `<Leader>db` | Toggle breakpoint |
| `<Leader>du` | DAP UI toggle |

### Test

| Key | Action |
| ---- | ----- |
| `<leader>tr` | Run nearest test |
| `<leader>tR` | Run all tests |
| `<leader>tf` | Run tests in file |
| `<leader>to` | Toggle test output |

### Window / Buffer

| Key | Action |
| ---- | ----- |
| `<C-h/j/k/l>` | Window navigation (tmux-aware) |
| `<C-PageDown/Up>` | Switch buffer |
| `<C-t>` | New buffer |
| `<C-q>` | Close buffer |

---

## 🛠️ Maintenance

### Update plugins

```vim
:NazoPlug sync      " Install/restore from the lock
:NazoPlug update    " Update all plugins
:NazoPlug install   " Install missing plugins
:NazoPlug restore   " Restore lock commits
:NazoPlug check     " Check install/lock status
:NazoPlug status    " Show plugin and lock status
:NazoPlug clean     " Remove plugins missing from specs/lock
:NazoPlug migrate   " Migrate existing lazy.nvim data
:NazoPlug build     " Run build hooks
```

### Reload config

```vim
:source %   " Source current buffer
```

---

## 🔧 Customization

Any Lua file added under `lua/plugins/` will be auto-loaded.

```lua
-- lua/plugins/my-config.lua

-- Add a plugin
return {
  "folke/zen-mode.nvim",
  opts = {}
}
```

You can also override existing plugin settings in the same file:

```lua
return {
  "folke/snacks.nvim",
  opts = { dashboard = { enabled = false } }
}
```

> **Note**: Only applies when installed via the Clone method (Option 2).

---

## 🏗️ Nix Integration

This distribution is fully managed as a Nix flake.

```bash
# Isolated launch (non-destructive)
nix run github:nazozokc/NazoVim

# Dev shell with LSP/formatter included
nix develop github:nazozokc/NazoVim

# Build config files only
nix build github:nazozokc/NazoVim

# Supported platforms
# x86_64-linux / aarch64-linux / aarch64-darwin
```

---

## 🐛 Contributing

Issues and PRs are always welcome.
<!-- markdownlint-disable MD013 -->
For questions, head over to [GitHub Discussions](https://github.com/nazozokc/NazoVim/discussions).
<!-- markdownlint-enable MD013 -->

Issue templates are available for:

- 🐛 **Bug Report** — Include reproduction steps, Neovim version, and error logs
- ✨ **Feature Request** — Describe your motivation and proposed solution
- 🔌 **Plugin Proposal** — Include plugin name, URL, and a nazoplug spec snippet

---

## 📄 License

MIT © [nazozokc](https://github.com/nazozokc)
