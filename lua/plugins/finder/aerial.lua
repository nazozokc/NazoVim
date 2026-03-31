return {
	"stevearc/aerial.nvim",
	event = "LspAttach",
	opts = {
		backends = { "lsp", "treesitter", "markdown" },
		layout = {
			min_width = 30,
		},
		show_guides = true,
	},
}
