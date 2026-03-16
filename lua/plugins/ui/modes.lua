return {
	{
		"mvllow/modes.nvim",
		event = "VeryLazy",
		config = function()
			require("modes").setup({
				-- モードごとの色（Kanagawa準拠）
				colors = {
					normal = "#7e9cd8", -- blue
					insert = "#98bb6c", -- green
					visual = "#c0a36e", -- yellow
					command = "#957fb8", -- purple
					replace = "#e46876", -- red
					terminal = "#a3d4d5", -- cyan
				},

				-- 変更対象
				line_nr = true, -- 行番号
				cursor_line_nr = true, -- カーソル行番号
			})
		end,
	},
}
