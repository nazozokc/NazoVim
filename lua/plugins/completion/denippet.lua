return {
	-- denippet 本体（最小）
	{
		"uga-rosa/denippet.vim",
		event = "InsertEnter",
		init = function()
			-- 起動前に設定（重要：config に書くと遅い）
			vim.g.denippet_snippet_dirs = {
				vim.fn.stdpath("config") .. "/snippets",
			}
		end,
	},

	-- nvim-cmp 連携（cmp 読まれた時だけ）
	{
		"uga-rosa/cmp-denippet",
		dependencies = { "uga-rosa/denippet.vim" },
		lazy = true,
	},

	-- VSCode スニペット auto import（必要な時だけ）
	{
		"ryoppippi/denippet-autoimport-vscode",
		event = "User DenopsReady", -- InsertEnter 削除（重さの元）
		dependencies = {
			"vim-denops/denops.vim",
			"rafamadriz/friendly-snippets",
		},
		config = function()
			-- 自動 import を抑制（初回だけ）
			vim.g.denippet_autoimport_vscode = {
				enabled = true,
				once = true,
			}
		end,
	},
}
