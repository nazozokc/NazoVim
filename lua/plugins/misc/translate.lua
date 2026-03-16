return {
	{
		"uga-rosa/translate.nvim",
		cmd = { "Translate" },
		config = function()
			require("translate").setup({
				default = {
					command = "google",
					from = "auto",
					to = "ja",
				},
			})

			vim.keymap.set("n", "<Leader>T", "<cmd>Translate ja<CR>", { desc = "Translate to Japanese" })
			vim.keymap.set("v", "<Leader>T", "<cmd>Translate ja<CR>", { desc = "Translate to Japanese" })
		end,
	},
}
