return {
	event = "InsertEnter",
	"hrsh7th/nvim-cmp",
	dependencies = {
		-- 補完ソース
		"hrsh7th/cmp-nvim-lsp",
		"hrsh7th/cmp-buffer",
		"hrsh7th/cmp-path",
		"hrsh7th/cmp-calc",

		-- スニペット
		"L3MON4D3/LuaSnip",
		"saadparwaiz1/cmp_luasnip",
		"rafamadriz/friendly-snippets",
	},

	config = function()
		local cmp = require("cmp")
		local luasnip = require("luasnip")

		require("luasnip.loaders.from_vscode").lazy_load()

		------------------------------------------------------------------
		-- ハイライト
		------------------------------------------------------------------
		vim.api.nvim_set_hl(0, "CmpGhostSnippet", {
			fg = "#727169",
			italic = true,
		})

		vim.api.nvim_set_hl(0, "CmpSnippetPreview", {
			fg = "#6e738d",
			italic = true,
		})

		------------------------------------------------------------------
		-- cmp 本体
		------------------------------------------------------------------
		cmp.setup({
			preselect = cmp.PreselectMode.Item,

			snippet = {
				expand = function(args)
					luasnip.lsp_expand(args.body)
				end,
			},

			window = {
				completion = cmp.config.window.bordered(),
				documentation = cmp.config.window.bordered(),
			},

			formatting = {
				fields = { "kind", "abbr", "menu" },
				format = function(entry, item)
					local icons = {
						Function = "󰊕",
						Snippet = "",
					}

					item.kind = (icons[item.kind] or "") .. " " .. item.kind
					item.menu = ({
						luasnip = "[SNIP]",
						nvim_lsp = "[LSP]",
						buffer = "[BUF]",
						path = "[PATH]",
					})[entry.source.name]

					return item
				end,
			},

			mapping = cmp.mapping.preset.insert({
				["<C-Space>"] = cmp.mapping.complete(),
				["<CR>"] = cmp.mapping.confirm({ select = true }),

				["<Tab>"] = function(fallback)
					if cmp.visible() then
						cmp.confirm({ select = true })
					elseif luasnip.expand_or_jumpable() then
						luasnip.expand_or_jump()
					else
						fallback()
					end
				end,

				["<S-Tab>"] = function(fallback)
					if luasnip.jumpable(-1) then
						luasnip.jump(-1)
					else
						fallback()
					end
				end,
			}),

			sources = {
				{ name = "luasnip", priority = 1000 },
				{ name = "nvim_lsp", priority = 900 },
				{ name = "path", priority = 500 },
				{ name = "buffer", priority = 250 },
			},

			experimental = {
				ghost_text = {
					hl_group = "CmpGhostSnippet",
				},
			},
		})

		------------------------------------------------------------------
		-- snippet hover ghost preview（修正版・本命）
		------------------------------------------------------------------
		local ns = vim.api.nvim_create_namespace("cmp_snippet_preview")

		cmp.event:on("complete_changed", function(event)
			vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)

			local entry = event.entry
			if not entry or entry.source.name ~= "luasnip" then
				return
			end

			local snippet = entry:get_insert_text()
			if not snippet then
				return
			end

			local preview = snippet
				:gsub("%$%b{}", function(s)
					return s:match("{(.-)}") or ""
				end)
				:gsub("%$%d+", "")
				:gsub("\n.*", "")

			local row, col = table.unpack(vim.api.nvim_win_get_cursor(0))
			row = row - 1

			vim.api.nvim_buf_set_extmark(0, ns, row, col, {
				virt_text = { { preview, "CmpSnippetPreview" } },
				virt_text_pos = "eol",
			})
		end)

		cmp.event:on("menu_closed", function()
			vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
		end)
	end,
}
