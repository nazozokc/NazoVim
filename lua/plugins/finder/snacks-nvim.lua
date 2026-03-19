return {
	"folke/snacks.nvim",
	priority = 1000,
	lazy = false,
	opts = {
		notifier = {
			enabled = false,
		},
		-- =========================
		-- Dashboard
		-- =========================
		dashboard = {
			sections = {
				{ section = "header" },
				{ icon = " ", title = "Recent Files", section = "recent_files", indent = 2, padding = 1 },
				{ icon = " ", title = "Projects", section = "projects", indent = 2, padding = 1 },
				{ icon = " ", title = "Keymaps", section = "keys", indent = 2, padding = 1 },
				{ section = "startup" },
			},
			autokeys = "asdfghjklqwertyuiop",
			preset = {
				keys = {
					{ icon = "", desc = "New file", key = "e", action = ":enew" },
					{ icon = "󰒲", desc = "Lazy", key = "z", action = ":Lazy" },
					{ icon = "󰈙", desc = "Oil", key = ".", action = ":Oil" },
					{ icon = "", desc = "Dotfiles", key = "d", action = ":Config" },
					{ icon = "󰈙", desc = "Files", key = "f", action = ":Telescope find_files" },
					{ icon = "", desc = "Restore Session", key = "s", section = "session" },
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
				local ok, ibl = pcall(require, "ibl")
				if ok and ibl then
					pcall(ibl.disable, 0)
				end
			end,
			on_close = function()
				vim.diagnostic.enable(true)
				vim.opt.signcolumn = "yes"
				local ok, ibl = pcall(require, "ibl")
				if ok and ibl then
					pcall(ibl.enable, 0)
				end
			end,
		},
	},
	config = function(_, opts)
		require("snacks").setup(opts)
	end,
}
