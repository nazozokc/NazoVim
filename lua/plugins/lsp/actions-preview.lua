return {
	"aznhe21/actions-preview.nvim",
	event = "LspAttach",
	config = function()
		require("actions-preview").setup({
			telescope = {
				sorting_strategy = "ascending",
				layout_config = {
					prompt_position = "top",
				},
			},
		})
	end,
}
