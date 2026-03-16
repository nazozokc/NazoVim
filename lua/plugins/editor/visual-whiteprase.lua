return {
	"mcauley-penney/visual-whitespace.nvim",
	event = "BufReadPost",
	opts = {
		enabled = true,
		highlight = { link = "Visual", default = true },
		match_types = {
			space = true,
			tab = true,
			nbsp = true,
			lead = false,
			trail = false,
		},
		list_chars = {
			space = ">",
			tab = "↦",
			nbsp = "␣",
			lead = "‹",
			trail = "->",
		},
		fileformat_chars = {
			unix = "↲",
			mac = "←",
			dos = "↙",
		},
		ignore = { filetypes = {}, buftypes = {} },
	},
}
