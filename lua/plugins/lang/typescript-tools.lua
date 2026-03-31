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
				client.server_capabilities.documentFormattingProvider = false
				client.server_capabilities.documentRangeFormattingProvider = false
				client.server_capabilities.semanticTokensProvider = nil

				local function bufmap(mode, lhs, rhs, desc)
					vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
				end

				bufmap("n", "<leader>oi", "<cmd>TSToolsOrganizeImports<CR>", "Organize imports")
				bufmap("n", "<leader>ru", "<cmd>TSToolsRemoveUnused<CR>", "Remove unused")
			end,

			settings = {
				-- Important: disable separate diagnostic server
				separate_diagnostic_server = false,
				publish_diagnostic_on = "save",

				-- Minimal completions
				complete_function_calls = false,
				include_completions_with_insert_text = false,

				-- Disable display features
				code_lens = "off",
				disable_member_code_lens = true,

				-- Disable inlay hints
				tsserver_file_preferences = {
					includeInlayParameterNameHints = "none",
					includeInlayParameterNameHintsWhenArgumentMatchesName = false,
					includeInlayFunctionParameterTypeHints = false,
					includeInlayVariableTypeHints = false,
					includeInlayPropertyDeclarationTypeHints = false,
					includeInlayFunctionLikeReturnTypeHints = false,
					includeInlayEnumMemberValueHints = false,
				},

				-- Lightweight file watching
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
