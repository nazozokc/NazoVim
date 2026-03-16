return {
	{
		"romgrk/barbar.nvim",
		event = "VeryLazy",
		dependencies = {
			"nvim-tree/nvim-web-devicons",
			"lewis6991/gitsigns.nvim",
		},
		init = function()
			vim.g.barbar_auto_setup = false
			vim.o.mouse = "a"
		end,
		opts = {
			animation = false,
			clickable = true,
			auto_hide = false, -- ← 安定重視
			focus_on_close = "left",
			sidebar_filetypes = { NvimTree = true },
			icons = {
				filetype = { enabled = true },
				button = "✕",
				modified = { button = "●" },
				pinned = { button = "📌", filename = true },
				separator = { left = "▎", right = "" },
			},
			maximum_padding = 1,
			minimum_padding = 1,
			maximum_length = 30,
			semantic_letters = true,
		},
		config = function(_, opts)
			require("barbar").setup(opts)
			local map = vim.keymap.set
			local o = { silent = true }

			map("n", "<C-A-Tab>", "<Cmd>BufferNext<CR>", o)
			map("n", "<C-A-S-Tab>", "<Cmd>BufferPrevious<CR>", o)

			map("n", "<C-PageDown>", "<Cmd>BufferNext<CR>", o)
			map("n", "<C-PageUp>", "<Cmd>BufferPrevious<CR>", o)

			map("n", "<C-t>", "<Cmd>enew<CR>", o)
			map("n", "<C-q>", "<Cmd>BufferClose<CR>", o)

			map("n", "<C-A-Space>", "<Cmd>BufferPick<CR>", o)

			map("n", "<ScrollWheelUp>", "<Cmd>BufferPrevious<CR>", o)
			map("n", "<ScrollWheelDown>", "<Cmd>BufferNext<CR>", o)
		end,
	},
}
