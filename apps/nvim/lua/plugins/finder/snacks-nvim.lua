return {
	"folke/snacks.nvim",
	priority = 1000,
	lazy = false,
	opts = {
		notifier = {
			enabled = true,
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
					{ icon = "󰙅", desc = "Explorer", key = ".", action = ":Neotree filesystem reveal right" },
					{
						icon = "",
						desc = "Dotfiles",
						key = "d",
						action = function()
							local dir = vim.fn.expand("~/ghq/github.com/nazozokc/dotfiles")
							if vim.fn.isdirectory(dir) == 0 then
								dir = vim.fn.stdpath("config")
							end
							require("snacks").picker.files({ cwd = dir })
						end,
					},
					{
						icon = "󰈙",
						desc = "Files",
						key = "f",
						action = function()
							require("snacks").picker.files()
						end,
					},
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
		-- Session は persistence.nvim で管理
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
			enabled = true,
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
