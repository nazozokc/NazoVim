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
- **🔧 Full LSP** — Multi-language support: TypeScript / Lua / Ruby / Nix / C / Java / Zig and more. Servers found on `PATH` are enabled automatically (no mason)
- **🎨 NazoVim theme** — Original blue-green dark palette with a transparent background
- **🧠 AI integration** — Built-in terminal integration for both Claude Code and opencode (`claudecode.lua` / `opencode.lua`)
- **🌊 Dashboard / Zen** — Built-in startup dashboard and distraction-free mode
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
| NazoVim built-in | LSP management (`lsp.lua`, `vim.lsp.config` / `vim.lsp.enable`, only servers found on `PATH`, `:NazoLspInfo`) |
| NazoVim built-in | File icons (`icons.lua`, devicons-compatible `get_icon` / `get_icon_by_filetype`) |
| NazoVim built-in | TypeScript / JavaScript LSP (`lsp.lua` `ts_ls` = typescript-language-server, formatting and semantic tokens disabled, `<leader>oi` / `<leader>ru`) |
| NazoVim built-in | Rust LSP (`lsp.lua` `rust_analyzer` = rust-analyzer, `<leader>rr` picks and runs a runnable) |
| NazoVim built-in | Java LSP (`lsp.lua` `jdtls` = jdt-language-server, one `-data` workspace per project) |
| NazoVim built-in | Completion (`completion.lua`, `vim.lsp.completion` plus snippet/buffer/path sources, `<C-Space>` / `<Tab>` / `<S-Tab>` / `<CR>`) |
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
| NazoVim built-in | Lua/Neovim API type completion (`lsp.lua` passes `$VIMRUNTIME` and nazoplug to the lua_ls `workspace.library`) |

### Fuzzy Finder / Navigation

| Plugin | Purpose |
| ------ | ------ |
| NazoVim built-in | Startup dashboard (`dashboard.lua`, `:NazoDashboard`) |
| NazoVim built-in | Zen mode (`zen.lua`, `<leader>z` / `:NazoZen`) |
| NazoVim built-in | Status column merging signs, folds and line numbers (`statuscolumn.lua`, `:NazoStatuscolumn`), and quickfile that creates missing parent directories on write (`quickfile.lua`) |
| NazoVim built-in | File, buffer, recent-item, and text-search picker (`picker.lua`) |
| NazoVim built-in | Buffer-based file browser (`file_browser.lua`, `<leader>m` / `<leader>n`); replaces oil, neo-tree and yazi |
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
| NazoVim built-in | Rich Markdown rendering (`markdown_render.lua`) |
| NazoVim built-in | Inline color code preview |

### Git (Plugins)

| Plugin | Purpose |
| ------ | ------ |
| NazoVim built-in | Git change signs, hunk navigation and preview, line blame (`git_signs.lua`) |
| NazoVim built-in | Git change list, history, and conflict selection (`git_review.lua`) |
| NazoVim built-in | Floating LazyGit terminal (`lazygit.lua`) |
| NazoVim built-in | Git status, stage/unstage, diff, log, blame and any `git` subcommand (`git.lua`, `:Git` / `:NazoGitStatus` / `<leader>gs`) |
| NazoVim built-in | GitHub issue / PR lists, details, creation, title/body editing, comments, and close/reopen (`github.lua`, uses `gh` CLI) |
| NazoVim built-in | GitHub notifications and issue / PR search (`github.lua`); discussion create/edit/delete/reply, comment management, poll voting, accepted answers, upvotes, reactions, categories, subscriptions, close/reopen (`github_discussions.lua`) |
| NazoVim built-in | Issue / PR labels, assignees, milestones, project membership, reactions, and PR reviewer requests (`github_metadata.lua`) |
| NazoVim built-in | GitHub issue pinning, notification subscriptions, and linked branches (`github_issue_extras.lua`) |
| NazoVim built-in | PR checks, merge, checkout, ready/draft, and branch updates (`github_pr_actions.lua`) |
| NazoVim built-in | Pull request diff, inline comments, thread replies/resolution, and overall reviews (`github_review.lua`) |
| NazoVim built-in | PR commits, changed files and check runs with diff previews (`github_pr_details.lua`) |
| NazoVim built-in | Project board item lists, status changes, issue/PR additions, and archiving (`github_projects.lua`) |
| NazoVim built-in | Gist listing with browser links (`github_gists.lua`) |

### Editor

| Plugin | Purpose |
| ------ | ------ |
| NazoVim built-in | Treesitter (`treesitter.lua`, `vim.treesitter.start`, grammars supplied by Nix, `:NazoTreesitterInfo`) |
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
| NazoVim built-in | Codex CLI integration (`codex.lua`, `:Codex` / `:CodexToggle`, `<C-q>` to close) |
| NazoVim built-in | Claude Code CLI integration (`claudecode.lua`, `:ClaudeCode` / `:ClaudeCodeToggle` / `:ClaudeCodeFocus`, `<C-q>` to close) |
| NazoVim built-in | opencode CLI integration (`opencode.lua`, `:OpenCode` / `:OC`, `<C-.>` to toggle) |
| NazoVim built-in | Non-interactive AI client (`ai_ask.lua`, streams `claude -p --tools "" --restricted --strict-mcp-config --safe-mode` / `codex exec --sandbox read-only --ephemeral --ignore-rules --ignore-user-config` / `opencode run --pure` into a right split. Refuses `.env`, private keys and credentials, redacts tokens and passwords, and caps context, prompt, output and time; `:NazoAI` / `<leader>aa` / `<leader>ae` / `<leader>at` / `<leader>a?` / `:NazoAIDiff` / `:NazoAIQuickfix` / `:NazoAIExplain` / `:NazoAIFix` / `:NazoAIReview` / `:NazoAITest` / `:NazoAIDocs`) |

### Debug / Test

| Plugin | Purpose |
| ------ | ------ |
| NazoVim built-in | DAP client (`dap.lua`, a Debug Adapter Protocol implementation over stdio; launches the `js-debug` adapter, `<F5>` / `<F10>` / `<F11>` / `<F12>` for execution control, `<leader>db` to toggle a breakpoint, `<leader>dB` to list them, `<leader>dl` to start, `<leader>de` to evaluate, `<leader>dq` to stop, `:NazoDapInfo` for the state) |
| NazoVim built-in | DAP information panel (`dap_ui.lua`: expandable scopes, frame selection, watches) |
| NazoVim built-in | JS/TS debug adapter launcher (`dap.lua` starts `js-debug` in TCP mode; supplied by the devShell) |
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
| `<Leader><Leader>` | File search (built-in picker) |
| `<Leader>/` | Live Grep |
| `<Leader>b` | Buffer list |
| `<Leader>r` | Recent files |
| `<Leader>h` | Clear search highlight |
| `<Leader>z` | Zen mode |
| `<Leader>m` / `<Leader>n` | File browser |
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
| `<Leader>oC` | PR commits, changed files, and check runs; `<CR>` opens a commit diff or file patch, `gx` opens GitHub |
| `<Leader>oB` | GitHub Projects; `<CR>` on an item changes its status or archives it, and issues/PRs can be added |
| `<Leader>oG` | List gists; `<CR>` opens one in the browser and `y` copies its URL |
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
| `<Leader>aa` | Ask NazoAI (claude / codex / opencode CLI) |
| `<Leader>ae` | Apply the answer's code block to the buffer (asks first) |
| `<Leader>at` | Toggle the NazoAI panel |
| `<Leader>a?` | Select the NazoAI provider |
| `<Leader>ad` | Attach the git diff |
| `<Leader>aq` | Attach the quickfix list |
| `<Leader>aE` | Explain the buffer or range |
| `<Leader>aF` | Ask for a corrected version |
| `<Leader>aR` | Review for correctness and security |
| `<Leader>aT` | Ask for tests |
| `<Leader>aD` | Ask for documentation |
| `<Leader>Cc` | Claude Code toggle |
| `<Leader>Cf` | Claude Code focus |
| `<Leader>oa` | opencode ask (mentions the current buffer as `@path`) |
| `<Leader>ox` | opencode command palette |
| `<C-.>` | opencode toggle |

NazoAI refuses `.env`, private keys and credential files, replaces tokens and passwords with `[REDACTED]`, disables Claude tools with `--restricted --strict-mcp-config --safe-mode` and sends its prompt over stdin, runs Codex with `--sandbox read-only` plus shell tools disabled and sends its prompt over stdin, runs opencode with `--pure` and an `OPENCODE_PERMISSION` that denies its built-in tools, rejects symlinks and control characters in paths, and prevents code-fence breakout. It asks before applying code (`g:nazovim_ai_apply_confirm = false` skips the prompt). Tune the limits with `g:nazovim_ai_max_context_bytes`, `g:nazovim_ai_max_prompt_bytes`, `g:nazovim_ai_max_apply_bytes`, `g:nazovim_ai_max_output_bytes`, `g:nazovim_ai_timeout` (seconds) and `g:nazovim_ai_quickfix_items`.

### DAP

| Key | Action |
| ---- | ----- |
| `<F5>` | Run / continue |
| `<F10>` | Step over |
| `<F11>` | Step in |
| `<F12>` | Step out |
| `<Leader>db` | Toggle breakpoint |
| `<Leader>dB` | List breakpoints |
| `<Leader>dl` | Start debugging |
| `<Leader>de` | Evaluate expression |
| `<Leader>dq` | Stop the session |
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

NazoVim ships no external plugins. To add one, list an import in
`lua/plugins.lua` and drop the spec under `lua/plugins/<group>/`.

```lua
-- lua/plugins.lua
return {
  { import = "plugins.my-group" },
}
```

```lua
-- lua/plugins/my-group/zen-mode.lua
return {
  "folke/zen-mode.nvim",
  opts = {},
}
```

Added plugins are installed by `:NazoPlug sync` and recorded in `nazoplug-lock.json`.
Loading timing is set in the `plugins` table of `lua/config/startup.lua`.

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
