return {
	"stevearc/oil.nvim",
	cmd = "Oil",
	keys = {
		{ "<leader>m", "<cmd>Oil<CR>", desc = "Open Oil" },
	},
	dependencies = {
		"echasnovski/mini.icons",
		"refractalize/oil-git-status.nvim",
		"folke/snacks.nvim",
	},

	opts = function()
		return {
			use_default_keymaps = false,

			keymaps = {
				["?"] = "actions.show_help",
				["gx"] = "actions.open_external",
				["<CR>"] = "actions.select",
				["-"] = "actions.parent",
				["<C-p>"] = "actions.preview",
				["<esc>"] = "actions.close",
				["<C-l>"] = "actions.refresh",
				["_"] = "actions.open_cwd",
				["`"] = "actions.cd",
				["~"] = "actions.tcd",
				["g."] = "actions.toggle_hidden",
				["<C-s>"] = "actions.select_vsplit",
				["<C-h>"] = "actions.select_split",
				["<C-t>"] = "actions.select_tab",
			},
		}
	end,

	config = function(_, opts)
		require("oil").setup(opts)
		require("oil-git-status").setup()

		-- Oil 用 autocmd
		vim.api.nvim_create_autocmd("FileType", {
			pattern = "oil",
			callback = function()
				vim.b.snacks_main = true
			end,
		})
	end,
}
