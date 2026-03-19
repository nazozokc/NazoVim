-- ~/.config/nvim/lua/plugins/indent-blankline.lua
return {
	"lukas-reineke/indent-blankline.nvim",
	event = "VeryLazy",
	main = "ibl",
	opts = {
		indent = {
			char = "│",
		},
		scope = {
			enabled = false,
		},
	},
}
