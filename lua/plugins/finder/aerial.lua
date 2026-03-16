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
	keys = {
		{ "<leader>a", "<cmd>AerialToggle!<CR>", desc = "Aerial Toggle" },
	},
}
