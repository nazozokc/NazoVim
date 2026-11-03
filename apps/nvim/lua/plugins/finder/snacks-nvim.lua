return {
	"folke/snacks.nvim",
	priority = 1000,
	lazy = false,
	opts = {
		notifier = {
			enabled = false, -- NazoVim owns vim.notify.
		},
		-- =========================
		-- Dashboard
		-- =========================
		dashboard = {
			enabled = true,
			sections = {
				{ section = "header" },
				{ icon = " ", title = "Recent Files", section = "recent_files", indent = 2, padding = 1 },
				{ icon = " ", title = "Projects", section = "projects", indent = 2, padding = 1 },
				{ icon = " ", title = "Keymaps", section = "keys", indent = 2, padding = 1 },
				-- The startup section requires lazy.nvim's stats module
				{ section = "startup", enabled = package.loaded.lazy ~= nil },
			},
			autokeys = "asdfghjklqwertyuiop",
			preset = {
				keys = {
					{ icon = "", desc = "New file", key = "e", action = ":enew" },
					{ icon = "󰒲", desc = "Plugins", key = "z", action = ":NazoPlug" },
					{ icon = "󰈙", desc = "Browse files", key = ".", action = ":NazoFiles" },
					{ icon = "", desc = "Dotfiles", key = "d", action = ":Config" },
					{ icon = "󰈙", desc = "Files", key = "f", action = ":NazoPickFiles" },
					{ icon = "󰅚", desc = "Quit", key = "q", action = ":qa" },
				},
				header = [[
 █   █  ███  █████  ███  █   █ ███ █   █
 ██  █ █   █     █ █   █ █   █  █  ██ ██
 █ █ █ █   █    █  █   █ █   █  █  █ █ █
 █  ██ █████   █   █   █ █   █  █  █   █
 █   █ █   █  █    █   █  █ █   █  █   █
 █   █ █   █ █     █   █  █ █   █  █   █
 █   █ █   █ █████  ███    █   ███ █   █

a neovim distribution]],
			},
		},
		-- Session は NazoVim の独立機能で管理
		session = {
			enabled = false,
		},
		-- =========================
		-- Picker
		-- =========================
		picker = {
			enabled = true,
			layout = {
				preset = "ivy",
			},
			win = {
				border = "rounded",
			},
			sources = {
				files = {
					hidden = true,
					ignored = false,
					follow = true,
				},
				grep = {
					hidden = true,
					ignored = false,
				},
				buffers = {
					sort_lastused = true,
				},
				recent = {
					filter = function(item)
						return vim.fn.filereadable(item.file or "") == 1
					end,
				},
			},
		},
		-- =========================
		-- Quickfile
		-- =========================
		quickfile = {
			enabled = true,
		},
		-- =========================
		-- Statuscolumn
		-- =========================
		statuscolumn = {
			enabled = true,
			left = { "mark", "sign" },
			right = { "fold", "number" },
		},
		-- =========================
		-- Words
		-- =========================
		words = {
			enabled = false, -- References are owned by nazovim.references.
			debounce = 200,
			modes = { "n", "v" },
			highlight = {
				fg = nil,
				bg = "#2a2e36",
				underline = false,
				bold = false,
			},
		},
		-- =========================
		-- Zen (安全版)
		-- =========================
		zen = {
			enabled = true,
			on_open = function()
				vim.diagnostic.enable(false)
				vim.opt.signcolumn = "no"
			end,
			on_close = function()
				vim.diagnostic.enable(true)
				vim.opt.signcolumn = "yes"
			end,
		},
	},
	config = function(_, opts)
		require("snacks").setup(opts)
	end,
}
