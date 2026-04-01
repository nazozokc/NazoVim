return {
	"lewis6991/satellite.nvim",
	event = "BufReadPre",
	config = function()
		require("satellite").setup({
			current_only = true,
			excluded_filetypes = { "neo-tree", "prompt", "help" },
		})
	end,
}
