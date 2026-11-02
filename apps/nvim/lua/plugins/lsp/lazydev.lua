return {
	"folke/lazydev.nvim",
	ft = "lua",
	opts = {
		library = {
			-- Load snacks.nvim types
			{ path = "snacks.nvim", words = { "Snacks" } },
			-- Load nazoplug spec types
			{ path = "nazoplug", words = { "NazoSpec" } },
		},
	},
}
