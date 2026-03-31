return {
	"folke/lazydev.nvim",
	ft = "lua",
	opts = {
		library = {
			-- Load snacks.nvim types
			{ path = "snacks.nvim", words = { "Snacks" } },
			-- Load lazy.nvim types
			{ path = "lazy.nvim", words = { "LazySpec", "LazyConfig" } },
		},
	},
}
