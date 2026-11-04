---
name: neovim
description: When editing NazoVim Neovim config, adding plugins, or optimizing startup time
---

# NazoVim Neovim Configuration Skill

## When to Use

- When adding or removing built-in features under `lua/nazovim/`
- When adding an external plugin through nazoplug
- When changing LSP, DAP, or formatter configuration
- When optimizing startup time

## Directory Structure

```text
lua/
├── config/
│   ├── options.lua   # vim.opt settings
│   ├── keymaps.lua   # Global keymaps
│   ├── autocmds.lua  # Autocommands
│   └── startup.lua   # Per-plugin loading timing
├── nazovim/          # Built-in features (one module per feature)
│   ├── features.lua  # Feature registry: name + phase
│   └── <feature>.lua # setup() called by the registry
└── plugins.lua       # Extra plugin imports (empty by default)
```

NazoVim ships no external plugins: `nazoplug-lock.json` is `{}`. Everything is a
built-in module registered in `lua/nazovim/features.lua`, so a new capability
is a new module there, not a new plugin.

## Feature Addition Checklist

1. Check whether an existing `lua/nazovim/` module already covers the role
2. Add `lua/nazovim/<feature>.lua` with a `setup()` function
3. Register it in `lua/nazovim/features.lua` with a phase:

| Phase          | Use Case                          |
| -------------- | --------------------------------- |
| `start`        | Everything needed at startup      |
| `AfterPlugins` | Needs nazoplug to be initialized  |
| `VimEnter`     | UI that waits for the first frame |
| `CmdlineEnter` | Command-line only                 |

1. Add a headless test to `apps/nvim/tests/features_test.lua`
2. Verify startup time: `nvim --startuptime /tmp/startuptime.log`

## External Plugin Checklist (only when unavoidable)

1. Put the spec under `lua/plugins/<group>/` and add
   `{ import = "plugins.<group>" }` to `lua/plugins.lua`
2. Pick a loading event (`VeryLazy`, `InsertEnter`, `LspAttach`, `cmd`, ...)
   or set the timing in `lua/config/startup.lua`
3. Run `:NazoPlug sync` and commit the updated `nazoplug-lock.json`

## Key Rules

- Never call `require()` outside of `config` (loads at startup)
- Keep modules independent — no cross-feature requires unless the target is a utility
- UI choices go through `vim.ui.select` / `vim.ui.input` so tests can stub them
- Keep configs minimal — leverage Neovim defaults where possible

## Verification

```bash
# Startup check (no errors)
nvim --headless \
  --startuptime /tmp/startuptime.log \
  -c "lua vim.defer_fn(function() vim.cmd('qall!') end, 500)" \
  2>/tmp/nvim-stderr.log || true

# Check for errors
grep -E "(^E[0-9]+:|Error detected|Error in lua)" /tmp/nvim-stderr.log

# Check startup time
tail -5 /tmp/startuptime.log
```

## CI Workflow

The `nvim.yml` workflow runs on push to main and PRs:

- Installs plugins via `Lazy! sync`
- Checks Neovim starts without errors
- Uploads logs on failure
