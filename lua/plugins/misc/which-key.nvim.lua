return {
	"folke/which-key.nvim",
	event = "VimEnter",
	opts = {
		preset = "modern", -- 表示を今風に
		delay = 200, -- 反応速度（短いほどキビキビ）
		icons = {
			breadcrumb = "»",
			separator = "➜",
			group = "+",
		},
		win = {
			border = "rounded",
			padding = { 1, 2 },
		},
		layout = {
			spacing = 6,
		},
		show_help = false,
	},
}
