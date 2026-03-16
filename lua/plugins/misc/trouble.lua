-- plugins/trouble.lua
return {
	"folke/trouble.nvim",
	event = "InsertEnter",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	cmd = { "Trouble", "TroubleToggle" },
	keys = {
		{ "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "Toggle Diagnostics (Trouble)" },
		{ "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "Buffer Diagnostics" },
		{ "<leader>cs", "<cmd>Trouble symbols toggle<cr>", desc = "Symbols (Trouble)" },
		{ "<leader>cl", "<cmd>Trouble lsp toggle<cr>", desc = "LSP List" },
	},
	opts = {
		auto_close = false,
		auto_open = false,
		auto_preview = true,
		multiline = true,
		indent_guides = true,
		win = { position = "right", size = 40 },
		icons = { -- ←ここをテーブルで指定
			Error = "",
			Warning = "",
			Information = "",
			Hint = "",
		},
	},
	config = function(_, opts)
		local trouble = require("trouble")
		trouble.setup(opts)
	end,
}
