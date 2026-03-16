return {
	"folke/flash.nvim",
	event = "BufReadPost",
	opts = {},
	keys = {
		{
			"<CR>",
			mode = { "n", "x", "o" },
			function()
				require("flash").jump()
			end,
			desc = "Flash Jump",
		},
		{
			"<S-CR>",
			mode = { "n", "x", "o" },
			function()
				require("flash").treesitter()
			end,
			desc = "Flash Treesitter",
		},
	},
}
