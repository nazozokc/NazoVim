return {
	"nvim-telescope/telescope-fzf-native.nvim",
	lazy = true,
	build = "make",
	config = function()
		require("telescope").load_extension("fzf")
	end,
}
