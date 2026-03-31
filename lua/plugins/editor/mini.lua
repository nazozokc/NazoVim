return {
	-- 1. mini.ai (text objects, loaded early for editing)
	{
		"echasnovski/mini.ai",
		version = false,
		event = "VeryLazy",
		config = function()
			require("mini.ai").setup({ mappings = { around = "a", inside = "i" } })
		end,
	},

	-- 2. mini.surround (depends on ai, same timing)
	{
		"echasnovski/mini.surround",
		version = false,
		-- Changed to keys: loads only when key is pressed
		keys = {
			{ "sa", desc = "Add surrounding" },
			{ "sd", desc = "Delete surrounding" },
			{ "sr", desc = "Replace surrounding" },
			{ "sn", desc = "Update n_lines" },
		},
		config = function()
			require("mini.surround").setup({
				mappings = {
					add = "sa",
					delete = "sd",
					replace = "sr",
					update_n_lines = "sn",
				},
			})
		end,
	},

	-- 3. mini.comment (loaded when editing)
	{
		"echasnovski/mini.comment",
		version = false,
		event = "BufReadPre",
		config = function()
			require("mini.comment").setup({ options = { ignore_blank_line = true, start_of_line = false } })
		end,
	},

	-- 4. mini.indentscope (visual, loaded when displayed)
	{
		"echasnovski/mini.indentscope",
		version = false,
		event = "BufReadPost",
		config = function()
			require("mini.indentscope").setup({
				draw = {
					delay = 100,
					animation = function()
						return 0
					end,
				},
			})
		end,
	},

	-- 5. mini.jump (movement, loaded on first cursor move)
	{
		"echasnovski/mini.jump",
		version = false,
		event = "CursorMoved",
		config = function()
			require("mini.jump").setup({ mappings = { repeat_forward = ";", repeat_backward = "," } })
		end,
	},
}
