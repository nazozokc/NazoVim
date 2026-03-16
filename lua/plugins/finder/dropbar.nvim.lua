return {
	"Bekaboo/dropbar.nvim",
	event = "BufReadPost",
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
	},
	config = function()
		local dropbar = require("dropbar")
		local sources = require("dropbar.sources")
		local utils = require("dropbar.utils")

		dropbar.setup({
			bar = {
				sources = function(buf, _)
					if vim.bo[buf].ft == "lua" then
						return {
							sources.path,
							sources.treesitter,
						}
					end
					return {
						sources.path,
						sources.treesitter,
					}
				end,
			},
			menu = {
				keymaps = {
					["l"] = utils.menu.confirm,
					["h"] = utils.menu.close,
					["<CR>"] = utils.menu.confirm,
					["q"] = utils.menu.close,
					["<Esc>"] = utils.menu.close,
				},
			},
		})
	end,
}
