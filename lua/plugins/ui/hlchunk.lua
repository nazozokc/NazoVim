return {
	"shellRaining/hlchunk.nvim",
	event = { "BufReadPost" },
	config = function()
		require("hlchunk").setup({
			indent = { enable = true, use_treesitter = false, chars = { "│" }, style = { "#806d9c" }, priority = 10 },
			chunk = { enable = true },
			blank = { enable = false },
		})
	end,
}
