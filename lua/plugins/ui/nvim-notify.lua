return {
	"rcarriga/nvim-notify",
	lazy = true,
	config = function()
		local notify = require("notify")

		notify.setup({
			stages = "fade_in_slide_out",
			timeout = 2500,
			top_down = false,
			render = "compact",
			background_colour = "#000000",
			max_width = math.floor(vim.o.columns * 0.4),
		})

		vim.notify = notify
	end,
}
