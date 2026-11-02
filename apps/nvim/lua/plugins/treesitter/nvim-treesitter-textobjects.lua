return {
	"nvim-treesitter/nvim-treesitter-textobjects",
	event = "VeryLazy",
	dependencies = { "nvim-treesitter/nvim-treesitter" },
	-- Config is merged into nvim-treesitter.lua's setup() call
	-- to avoid the fragility of calling require("nvim-treesitter").setup() twice.
}
