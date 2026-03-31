return {
	{
		"mvllow/modes.nvim",
		event = "VeryLazy",
		config = function()
			require("modes").setup({
				-- Kanagawa-compliant colors per mode
				colors = {
					normal = "#7e9cd8", -- blue
					insert = "#98bb6c", -- green
					visual = "#c0a36e", -- yellow
					command = "#957fb8", -- purple
					replace = "#e46876", -- red
					terminal = "#a3d4d5", -- cyan
				},

				-- Targets
				line_nr = true,
				cursor_line_nr = true,
			})
		end,
	},
}
