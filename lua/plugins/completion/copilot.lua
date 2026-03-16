return {
	"zbirenbaum/copilot.lua",
	cmd = { "Copilot", "CopilotChat" },
	config = function()
		require("copilot").setup({
			suggestion = {
				enabled = true,
				auto_trigger = true,
				debounce = 75,
				keymap = {
					accept = "<Tab>",
					next = "<C-n>",
					prev = "<C-p>",
					dismiss = "<C-e>",
				},
			},
			panel = { enabled = false },
		})
	end,
}
