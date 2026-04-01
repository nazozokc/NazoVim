-- =========================================================
-- Bootstrap lazy.nvim
-- =========================================================
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.uv.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable",
		lazypath,
	})
end

vim.opt.rtp:prepend(lazypath)

vim.opt.rtp:prepend(vim.fn.stdpath("data") .. "/site")

-- =========================================================
-- Basic UI options
-- =========================================================
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.cursorline = true

-- Disable relative number in Insert mode
vim.api.nvim_create_autocmd("InsertEnter", {
	callback = function()
		vim.opt.relativenumber = false
	end,
})

vim.api.nvim_create_autocmd("InsertLeave", {
	callback = function()
		vim.opt.relativenumber = true
	end,
})

-- =========================================================
-- Load configs
-- =========================================================
require("vim-options")
require("lazy").setup("plugins", {
	rocks = {
		enabled = false,
	},
	performance = {
		cache = {
			enabled = true,
		},
		reset_packpath = true,
		rtp = {
			reset = true,
			disabled_plugins = {
				"gzip",
				"matchit",
				"matchparen",
				"netrwPlugin",
				"tarPlugin",
				"tohtml",
				"tutor",
				"zipPlugin",
			},
		},
	},
})

-- =========================================================
-- Keymaps
-- =========================================================
local map = vim.keymap.set

-- ---------------------------------------------------------
-- UI / Toggle
-- ---------------------------------------------------------
map("n", "<leader>t", ":ToggleTerm<CR>", { desc = "Toggle terminal" })
map("n", "<leader>c", function()
	local dotfiles = vim.fn.expand("$HOME/dotfiles")
	if vim.uv.fs_stat(dotfiles) then
		vim.cmd("Oil " .. dotfiles)
	else
		vim.notify("Dotfiles directory not found at " .. dotfiles, vim.log.levels.WARN)
	end
end, { desc = "Open dotfiles in Oil" })
map("n", "<leader>so", ":AerialToggle!<CR>", { desc = "Toggle Aerial" })
map("n", "<F2>", function()
	require("snacks").zen.toggle()
end, { desc = "Toggle Zen Mode" })
map("n", "<leader>e", "<cmd>Trouble diagnostics toggle<cr>", { desc = "Toggle Trouble" })

-- ---------------------------------------------------------
-- LSP (Lspsaga / Actions)
-- ---------------------------------------------------------
map("n", "ga", "<cmd>Lspsaga code_action<CR>", { desc = "Code Action" })
map("n", "gd", "<cmd>Lspsaga goto_definition<CR>", { desc = "Go to Definition" })

map("n", "<leader>ca", function()
	require("actions-preview").code_actions()
end, { desc = "Code Action (preview)" })

-- ---------------------------------------------------------
-- Snacks.nvim (Picker / Zen)
-- ---------------------------------------------------------
map("n", "<leader><leader>", function()
	require("snacks.picker").files()
end, { desc = "Files" })

map("n", "<leader>/", function()
	require("snacks.picker").grep()
end, { desc = "Live Grep" })

map("n", "<leader>b", function()
	require("snacks.picker").buffers()
end, { desc = "Buffers" })

map("n", "<leader>r", function()
	require("snacks.picker").recent()
end, { desc = "Recent Files" })

map("n", "<leader>z", function()
	require("snacks").zen.toggle()
end, { desc = "Zen Mode" })

-- ---------------------------------------------------------
-- Dropbar.nvim
-- ---------------------------------------------------------
map("n", "<leader>;", function()
	require("dropbar.api").pick()
end, { desc = "Dropbar pick symbol" })

map("n", "gp", function()
	require("dropbar.api").open()
end, { desc = "Dropbar open" })
