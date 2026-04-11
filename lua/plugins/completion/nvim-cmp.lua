return {
	"hrsh7th/nvim-cmp",
	event = "InsertEnter",

	dependencies = {
		-- Completion sources
		"hrsh7th/cmp-nvim-lsp",
		"hrsh7th/cmp-buffer",
		"hrsh7th/cmp-path",
		"hrsh7th/cmp-calc",
		"zbirenbaum/copilot-cmp",

		-- Snippets
		"L3MON4D3/LuaSnip",
		"saadparwaiz1/cmp_luasnip",
		"rafamadriz/friendly-snippets",

		-- TailwindCSS color display
		"roobert/tailwindcss-colorizer-cmp.nvim",
	},

	config = function()
		local cmp = require("cmp")
		local luasnip = require("luasnip")
		local tailwindcss_colorizer = require("tailwindcss-colorizer-cmp")

		require("luasnip.loaders.from_vscode").lazy_load()

		------------------------------------------------------------------
		-- Highlights
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
		-- cmp core
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

					tailwindcss_colorizer.formatter(entry, item)

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
				{ name = "copilot", priority = 1050 },
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
		-- snippet hover ghost preview
		-- 選択中のスニペットを行末にプレビュー表示
		------------------------------------------------------------------
		local ns = vim.api.nvim_create_namespace("cmp_snippet_preview")

		vim.api.nvim_create_autocmd("CompleteChanged", {
			callback = function()
				local ok, err = pcall(function()
					local info = vim.fn.complete_info()

					if not info.pum_visible then
						vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
						return
					end

					local selected = info.selected
					if selected < 0 then
						vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
						return
					end

					local item = info.items and info.items[selected + 1]
					if not item or not item.abbr or item.abbr == "" then
						vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
						return
					end

					-- スニペットのプレビューを生成（場所ホルダーを除去）
					local preview = item.abbr
						:gsub("%$%b{}", function(s)
							return s:match("{(.-)}") or ""
						end)
						:gsub("%$%d+", "")
						:gsub("\n.*", "")

					local row, col = vim.unpack(vim.api.nvim_win_get_cursor(0))
					row = row - 1

					vim.api.nvim_buf_set_extmark(0, ns, row, col, {
						virt_text = { { preview, "CmpSnippetPreview" } },
						virt_text_pos = "eol",
					})
				end)
				if not ok then
					vim.notify("[cmp] snippet preview error: " .. tostring(err), vim.log.levels.WARN)
				end
			end,
		})
	end,
}
