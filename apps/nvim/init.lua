-- =========================================================
-- Enable bytecode cache (ryoppippi pattern)
-- =========================================================
vim.loader.enable()

-- =========================================================
-- Load configs
-- =========================================================
require("config.options")
require("config.keymaps")
require("config.autocmds")

local disabled_plugins = {
	"gzip",
	"matchit",
	"matchparen",
	"netrwPlugin",
	"netrw",
	"tarPlugin",
	"tar",
	"tohtml",
	"tutor",
	"zipPlugin",
	"zip",
	"osc52",
	"rplugin",
	"man",
	"shada",
	"spellfile",
	"editorconfig",
}

if vim.env.NAZOVIM_NAZOPLUG_PATH and vim.env.NAZOVIM_NAZOPLUG_PATH ~= "" then
	vim.opt.rtp:prepend(vim.env.NAZOVIM_NAZOPLUG_PATH)
end

local ok, nazoplug = pcall(require, "nazoplug")
if not ok then
	error("nazoplug not found: " .. tostring(nazoplug))
end

local initialized = nazoplug.setup({
	spec = "plugins",
	defaults = {
		lazy = true,
	},
	install = {
		missing = vim.env.NAZOVIM_AUTO_INSTALL == "1",
	},
	disabled_plugins = disabled_plugins,
})
if not initialized then
	error("nazoplug setup failed")
end
