return {
	"dmmulroy/ts-error-translator.nvim",
	ft = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
	config = function()
		require("ts-error-translator").setup()
	end,
}
