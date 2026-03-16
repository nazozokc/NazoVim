return {
	"mattn/emmet-vim",
	event = "VeryLazy",
	config = function()
		-- HTML/CSS で有効
		vim.g.user_emmet_leader_key = "<C-e>" -- 好きなトリガー
	end,
}
