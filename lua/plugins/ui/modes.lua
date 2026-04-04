return {
	"mvllow/modes.nvim",
	event = "VeryLazy",
	config = function()
		require("modes").setup({
			colors = {
				normal = "#7e9cd8",
				insert = "#98bb6c",
				visual = "#c0a36e",
				command = "#957fb8",
				replace = "#e46876",
				terminal = "#a3d4d5",
			},
			line_nr = true,
			cursor_line_nr = true,
		})
	end,
}
