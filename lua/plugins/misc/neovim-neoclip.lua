return {
	"AckslD/nvim-neoclip.lua",
	event = "VeryLazy",
	config = function()
		require("neoclip").setup({
			preview = true,
			initial_mode = "insert",
			on_select = { close_telescope = true },
			on_paste = { close_telescope = true },
			on_replay = { close_telescope = true },
			on_custom_action = { close_telescope = true },
			keys = {
				telescope = {
					i = {
						select = "<cr>",
						paste = "<c-p>",
						paste_behind = "<c-k>",
						replay = "<c-q>",
						delete = "<c-d>",
						edit = "<c-e>",
						custom = {},
					},
					n = {
						select = "<cr>",
						paste = "p",
						paste_behind = "P",
						replay = "q",
						delete = "d",
						edit = "e",
						custom = {},
					},
				},
				fzf = {
					select = "default",
					paste = "ctrl-p",
					paste_behind = "ctrl-k",
					custom = {},
				},
			},
		})
	end,
}
