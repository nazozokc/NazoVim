return {
	"zeioth/garbage-day.nvim",
	event = "LspAttach",
	dependencies = "neovim/nvim-lspconfig",
	config = function()
		require("garbage-day").setup({
			aggressive_mode = false,
			excluded_lsp_clients = {
				"eslint",
				"tsserver",
			},
		})
	end,
}
