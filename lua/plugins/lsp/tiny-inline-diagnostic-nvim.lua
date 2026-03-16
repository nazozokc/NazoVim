return {
	"rachartier/tiny-inline-diagnostic.nvim",
	event = "VeryLazy",
	config = function()
		require("tiny-inline-diagnostic").setup({
			-- オプションいろいろいじれるよ
		})
		vim.diagnostic.config({ virtual_text = true }) -- 内蔵のやつ OFF
	end,
}
