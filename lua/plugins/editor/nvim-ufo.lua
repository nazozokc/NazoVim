return {
	"kevinhwang91/nvim-ufo",
	event = "BufReadPost",
	dependencies = "kevinhwang91/promise-async",
	config = function()
		vim.o.foldmethod = "expr"
		vim.o.foldexpr = "v:lua.vim.lsp.foldexpr()"
		vim.o.foldlevel = 99
		require("ufo").setup()
	end,
}
