return {
	"glepnir/lspsaga.nvim",
	event = "LspAttach",
	keys = { { "<leader>ca", "<cmd>Lspsaga code_action<CR>" } },
	branch = "main",
	config = function()
		require("lspsaga").setup({})
	end,
}
