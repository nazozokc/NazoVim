return {
	"petertriho/nvim-scrollbar",
	event = "BufReadPost",
	config = function()
		require("scrollbar").setup()
	end,
}
