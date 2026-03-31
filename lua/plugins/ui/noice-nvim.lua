return {
	{
		"folke/noice.nvim",
		dependencies = {
			"MunifTanjim/nui.nvim",
		},
		event = "VeryLazy",
		opts = {
			cmdline = {
				enabled = true,
				view = "cmdline_popup",
				format = {
					cmdline = { icon = ">>>", lang = "vim" },
					search_down = { icon = "🔍⌄", lang = "regex" },
					search_up = { icon = "🔍⌃", lang = "regex" },
					lua = { icon = "λ", lang = "lua" },
				},
			},
			messages = {
				enabled = true,
				view_search = "virtualtext",
			},
			popupmenu = {
				enabled = true,
				backend = "nui",
			},
			notify = {
				enabled = true,
			},
			lsp = {
				override = {
					["vim.lsp.util.convert_input_to_markdown_lines"] = true,
					["vim.lsp.util.stylize_markdown"] = true,
					["cmp.entry.get_documentation"] = true,
				},
				progress = { enabled = true, view = "mini" },
				hover = { enabled = true },
				signature = { enabled = true },
				message = { enabled = true },
			},
			presets = {
				bottom_search = true,
				command_palette = true,
				long_message_to_split = true,
			},
		},
		config = function(_, opts)
			require("noice").setup(opts)

			-- Register autocmd outside of presets
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
