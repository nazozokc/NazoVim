return {
	"akinsho/toggleterm.nvim",
	cmd = "ToggleTerm",
	version = "*",
	config = function()
		require("toggleterm").setup({
			direction = "float",
			float_opts = {
				border = "rounded",
			},
		})
	end,
}
