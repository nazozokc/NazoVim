return {
	"rachartier/tiny-inline-diagnostic.nvim",
	event = "VeryLazy",
	config = function()
		require("tiny-inline-diagnostic").setup({})
		vim.diagnostic.config({ virtual_text = true })
	end,
}
