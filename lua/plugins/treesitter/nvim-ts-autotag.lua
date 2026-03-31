return {
	"windwp/nvim-ts-autotag",
	ft = { "html", "jsx", "tsx", "vue", "svelte", "astro" },
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
	},
	config = function()
		require("nvim-ts-autotag").setup({
			enable = true,
			enable_rename = true,
			enable_close = true,
		})
	end,
}
