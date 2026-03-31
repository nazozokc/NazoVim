return {
	"simrat39/rust-tools.nvim",
	ft = { "rust" },
	dependencies = {
		"neovim/nvim-lspconfig",
		"nvim-lua/plenary.nvim",
		"folke/which-key.nvim",
	},
	config = function()
		local rt = require("rust-tools")

		rt.setup({
			tools = {
				autoSetHints = true,
				hover_with_actions = true,
			},
			server = {
				settings = {
					["rust-analyzer"] = {
						cargo = {
							allFeatures = true,
						},
						checkOnSave = {
							command = "clippy",
						},
					},
				},
				on_attach = function(_, bufnr)
					local wk = require("which-key")

					wk.add({
						{ "K", vim.lsp.buf.hover, buffer = bufnr, desc = "Hover docs" },
						{ "gd", vim.lsp.buf.definition, buffer = bufnr, desc = "Go to definition" },
						{ "gr", vim.lsp.buf.references, buffer = bufnr, desc = "References" },
						{ "gi", vim.lsp.buf.implementation, buffer = bufnr, desc = "Implementation" },
						{ "<leader>ca", vim.lsp.buf.code_action, buffer = bufnr, desc = "Code Action" },
						{ "<leader>rn", vim.lsp.buf.rename, buffer = bufnr, desc = "Rename" },
						{ "<leader>rr", rt.runnables.runnables, buffer = bufnr, desc = "Rust Runnables" },
						{ "<leader>rd", rt.debuggables.debuggables, buffer = bufnr, desc = "Rust Debuggables" },
					})

					-- Toggle Inlay Hints
					vim.keymap.set(
						"n",
						"<leader>th",
						rt.toggle_hints,
						{ buffer = bufnr, desc = "Toggle Rust Inlay Hints" }
					)
				end,
			},
		})
	end,
}
