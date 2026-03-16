return {
	"monaqa/dial.nvim",
	event = "VeryLazy",
	keys = { "<C-a>", "<C-x>" },
	config = function()
		local augend = require("dial.augend")

		require("dial.config").augends:register_group({
			default = {
				augend.integer.alias.decimal,
				augend.constant.alias.bool,
			},
		})
		augend.constant.new({
			elements = { "small", "medium", "large" },
			word = true,
			cyclic = true,
		})
		augend.constant.new({
			elements = { "let", "const", "var" },
			word = true,
			cyclic = true,
		})
	end,
}
