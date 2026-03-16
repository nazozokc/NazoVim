return {
	"kosayoda/nvim-lightbulb",
	event = { "LspAttach" },
	config = function()
		require("nvim-lightbulb").setup({
			autocmd = { enabled = true },
			sign = { enabled = false },
			virtual_text = {
				enabled = true,
				text = "💡",
			},
		})
	end,
}
