-- init.lua か plugins/noice.lua に
return {
	{
		"folke/noice.nvim",
		dependencies = {
			"MunifTanjim/nui.nvim",
			"rcarriga/nvim-notify", -- 通知をいい感じに
		},
		event = "VeryLazy",
		opts = {
			cmdline = {
				enabled = true,
				view = "cmdline_popup", -- 中央に出るやつ
				format = {
					cmdline = { icon = ">>>", lang = "vim" },
					search_down = { icon = "🔍⌄", lang = "regex" },
					search_up = { icon = "🔍⌃", lang = "regex" },
					lua = { icon = "λ", lang = "lua" },
				},
			},
			messages = {
				enabled = true,
				view_search = "virtualtext", -- 検索カウントを画面上に
			},
			popupmenu = {
				enabled = true,
				backend = "nui", -- cmp の補完でも動く
			},
			notify = {
				enabled = true, -- vim.notify を有効
			},
			lsp = {
				progress = { enabled = true, view = "mini" },
				hover = { enabled = true },
				signature = { enabled = true },
				message = { enabled = true },
			},
			presets = {
				bottom_search = true, -- /検索は下に表示
				command_palette = true, -- cmdline と補完をいい感じに
				long_message_to_split = true, -- 長い出力は split に
			},
		},
		config = function(_, opts)
			require("noice").setup(opts)

			-- presets の外で autocmd を登録
			vim.api.nvim_create_autocmd("ColorScheme", {
				callback = function()
					vim.cmd([[
          highlight NoicePopup guibg=none
          highlight NoicePopupBorder guibg=none
     ]])
				end,
			})
		end,
	},
}
