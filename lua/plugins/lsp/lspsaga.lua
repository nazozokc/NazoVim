return {
	"nvimdev/lspsaga.nvim",
	event = "LspAttach",
	keys = { { "<leader>ca", "<cmd>Lspsaga code_action<CR>" } },
	config = function()
		require("lspsaga").setup({})
	end,
}
