return {
	"RRethy/vim-illuminate",
	event = { "BufReadPost", "BufNewFile" },
	config = function()
		require("illuminate").configure({
			providers = {
				"lsp",
				"treesitter",
			},

			delay = 120,
			under_cursor = true,

			filetypes_denylist = {
				"NvimTree",
				"neo-tree",
				"TelescopePrompt",
				"lazy",
				"mason",
				"dashboard",
				"alpha",
				"help",
				"terminal",
			},

			large_file_cutoff = 5000,
			large_file_overrides = {
				providers = { "lsp" },
			},

			disable_keymaps = false,
		})

		-- Subtle highlight for Kanagawa
		vim.api.nvim_set_hl(0, "IlluminatedWordText", { underline = true })
		vim.api.nvim_set_hl(0, "IlluminatedWordRead", { underline = true })
		vim.api.nvim_set_hl(0, "IlluminatedWordWrite", { underline = true })
	end,
}
