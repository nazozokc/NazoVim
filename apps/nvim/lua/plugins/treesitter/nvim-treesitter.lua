return {
	"nvim-treesitter/nvim-treesitter",
	branch = "master",
	build = ":TSUpdate",
	event = { "BufReadPost", "BufNewFile" },
	config = function()
		require("nvim-treesitter").setup({
			parser_install_dir = vim.fn.stdpath("data") .. "/site",
			ensure_installed = {
				"javascript",
				"typescript",
				"tsx",
				"java",
				"python",
				"json",
				"html",
				"css",
				"lua",
				"vim",
				"vimdoc",
				"regex",
				"bash",
			},

			highlight = {
				enable = true,
				additional_vim_regex_highlighting = false,
			},

			indent = {
				enable = true,
			},
		})
	end,
}
