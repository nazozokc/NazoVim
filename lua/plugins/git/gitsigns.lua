return {
	"lewis6991/gitsigns.nvim",
	event = { "BufReadPre", "BufNewFile" },
	opts = {
		signs = {
			add = { text = "▎" },
			change = { text = "▎" },
			delete = { text = "▎" },
			topdelete = { text = "▎" },
			changedelete = { text = "▎" },
		},
		signcolumn = true,
		numhl = false,
		linehl = true,
		watch_gitdir = {
			follow_files = true,
		},
		current_line_blame = false,
		word_diff = false,
		update_debounce = 100,
		current_line_blame_opts = {
			delay = 500,
		},
	},
	keys = {
		{
			"]h",
			function()
				require("gitsigns").next_hunk()
			end,
			desc = "Next hunk",
		},
		{
			"[h",
			function()
				require("gitsigns").prev_hunk()
			end,
			desc = "Prev hunk",
		},
		{
			"<leader>gp",
			function()
				require("gitsigns").preview_hunk()
			end,
			desc = "Preview hunk",
		},
		{
			"<leader>gt",
			function()
				require("gitsigns").toggle_current_line_blame()
			end,
			desc = "Toggle blame",
		},
	},
}
