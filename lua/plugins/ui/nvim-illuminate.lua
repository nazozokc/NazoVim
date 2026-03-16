return {
	"RRethy/vim-illuminate",
	event = { "BufReadPost", "BufNewFile" },
	config = function()
		require("illuminate").configure({
			providers = {
				"lsp",
				"treesitter",
				-- "regex", -- ← 切る。マジでいらん
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
				providers = { "lsp" }, -- 重いファイルでは treesitter 切る
			},

			disable_keymaps = false,
		})

		-- Kanagawa向け：主張しすぎない色
		vim.api.nvim_set_hl(0, "IlluminatedWordText", { underline = true })
		vim.api.nvim_set_hl(0, "IlluminatedWordRead", { underline = true })
		vim.api.nvim_set_hl(0, "IlluminatedWordWrite", { underline = true })
	end,
}
