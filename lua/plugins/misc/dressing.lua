return {
	"stevearc/dressing.nvim",
	event = "VeryLazy",
	config = function()
		require("dressing").setup({
			input = {
				enabled = true,
				default_prompt = "Input",
				trim_prompt = true,
				title_pos = "left",
				start_mode = "insert",
				border = "rounded",
				relative = "cursor",
				prefer_width = 40,
				width = nil,
				max_width = { 140, 0.9 },
				min_width = { 20, 0.2 },
				buf_options = {},
				win_options = {
					wrap = false,
					list = true,
					listchars = "precedes:…,extends:…",
					sidescrolloff = 0,
				},
				mappings = {
					n = {
						["<Esc>"] = "Close",
						["<CR>"] = "Confirm",
					},
					i = {
						["<C-c>"] = "Close",
						["<CR>"] = "Confirm",
						["<Up>"] = "HistoryPrev",
						["<Down>"] = "HistoryNext",
					},
				},
				override = function(conf)
					return conf
				end,
				get_config = nil,
			},
			select = {
				enabled = false,
			},
		})
	end,
}
