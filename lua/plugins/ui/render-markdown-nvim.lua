return {
	"MeanderingProgrammer/render-markdown.nvim",
	ft = { "markdown" },
dependencies = {
	"nvim-treesitter/nvim-treesitter",
	"echasnovski/mini.nvim",
},
	opts = {
		heading = {
			enabled = true,
			icons = { "󰎤 ", "󰎧 ", "󰎪 ", "󰎭 ", "󰎱 ", "󰎳 " },
			signs = false,
		},

		code = {
			enabled = true,
			style = "full",
			width = "block",
			left_pad = 2,
			right_pad = 2,
			min_width = 80,
		},

		bullet = {
			enabled = true,
			icons = { "•", "◦", "▪" },
		},

		checkbox = {
			enabled = true,
			unchecked = "󰄱 ",
			checked = "󰄵 ",
			custom = {
				todo = { raw = "[~]", rendered = "󰥔 ", highlight = "DiagnosticWarn" },
			},
		},

		quote = {
			enabled = true,
			icon = "┃",
			repeat_linebreak = false,
		},

		pipe_table = {
			enabled = true,
			style = "full",
		},

		link = {
			enabled = true,
			image = "󰥶 ",
			hyperlink = "󰌹 ",
		},

		sign = {
			enabled = false,
		},
	},
}
