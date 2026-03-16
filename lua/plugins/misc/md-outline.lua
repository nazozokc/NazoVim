return {
	"tttol/md-outline.nvim",
	event = "BufReadPost",
	config = function()
		require("md-outline").setup({
			auto_open = false, -- default: true
		})
	end,
}
