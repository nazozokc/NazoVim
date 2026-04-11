return {
	-- denippet core (minimal)
	{
		"uga-rosa/denippet.vim",
		event = "InsertEnter",
		init = function()
			-- Configure before startup (important: slow if in config)
			vim.g.denippet_snippet_dirs = {
				vim.fn.stdpath("config") .. "/snippets",
			}
		end,
	},

	-- nvim-cmp integration
	{
		"uga-rosa/cmp-denippet",
		dependencies = { "uga-rosa/denippet.vim" },
		event = "InsertEnter",
	},

	-- VSCode snippets auto import
	{
		"ryoppippi/denippet-autoimport-vscode",
		event = "User DenopsReady",
		dependencies = {
			"vim-denops/denops.vim",
			"rafamadriz/friendly-snippets",
		},
		config = function()
			-- Suppress auto import (first time only)
			vim.g.denippet_autoimport_vscode = {
				enabled = true,
				once = true,
			}
		end,
	},
}
