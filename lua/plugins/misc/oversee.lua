return {
	"stevearc/overseer.nvim",
	cmd = { "OverseerRun", "OverseerToggle", "OverseerOpen" },
	keys = {
		{ "<leader>ot", "<cmd>OverseerToggle<cr>", desc = "Overseer Toggle" },
		{ "<leader>or", "<cmd>OverseerRun<cr>", desc = "Overseer Run" },
	},
	opts = {},
}
