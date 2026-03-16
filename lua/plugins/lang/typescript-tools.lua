return {
	"pmizio/typescript-tools.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"neovim/nvim-lspconfig",
	},
	ft = {
		"javascript",
		"javascriptreact",
		"typescript",
		"typescriptreact",
	},
	config = function()
		require("typescript-tools").setup({
			on_attach = function(client, bufnr)
				-- formatting 完全無効
				client.server_capabilities.documentFormattingProvider = false
				client.server_capabilities.documentRangeFormattingProvider = false

				-- semantic tokens 無効（かなり効く）
				client.server_capabilities.semanticTokensProvider = nil

				local function bufmap(mode, lhs, rhs)
					vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, silent = true })
				end

				bufmap("n", "gd", vim.lsp.buf.definition)
				bufmap("n", "gr", "<cmd>Telescope lsp_references<CR>")
				bufmap("n", "<leader>oi", "<cmd>TSToolsOrganizeImports<CR>")
				bufmap("n", "<leader>ru", "<cmd>TSToolsRemoveUnused<CR>")
			end,

			settings = {
				-- ===== 超重要 =====
				separate_diagnostic_server = false,
				publish_diagnostic_on = "save", -- insert_leave より軽い

				-- 補完を最小限に
				complete_function_calls = false,
				include_completions_with_insert_text = false,

				-- 表示系 全部オフ
				code_lens = "off",
				disable_member_code_lens = true,

				-- inlay hints 全無効
				tsserver_file_preferences = {
					includeInlayParameterNameHints = "none",
					includeInlayParameterNameHintsWhenArgumentMatchesName = false,
					includeInlayFunctionParameterTypeHints = false,
					includeInlayVariableTypeHints = false,
					includeInlayPropertyDeclarationTypeHints = false,
					includeInlayFunctionLikeReturnTypeHints = false,
					includeInlayEnumMemberValueHints = false,
				},

				-- ファイル監視を軽量化（CPU暴走防止）
				tsserver_watch_options = {
					watchFile = "useFsEvents",
					watchDirectory = "useFsEvents",
					fallbackPolling = "dynamicPriority",
				},

				tsserver_locale = "en",
			},
		})
	end,
}
