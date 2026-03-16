return {
	{
		"CopilotC-Nvim/CopilotChat.nvim",
		dependencies = {
			"nvim-lua/plenary.nvim",
		},
		cmd = { "CopilotChat" },
		opts = {},
	},
	{
		"zbirenbaum/copilot-cmp",
		cmd = { "Copilot", "CopilotChat" },
		config = function()
			require("copilot_cmp").setup({})
		end,
	},
}
