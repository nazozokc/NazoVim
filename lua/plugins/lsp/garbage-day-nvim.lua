return {
	"zeioth/garbage-day.nvim",
	cmd = { "GarbageDay" },
	dependencies = "neovim/nvim-lspconfig",
	config = function()
		require("garbage-day").setup({
			aggressive_mode = false,
			excluded_lsp_clients = {
				"eslint",
				"ts_ls",
			},
		})
	end,
}
