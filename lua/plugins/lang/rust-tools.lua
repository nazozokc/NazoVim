return {
	"simrat39/rust-tools.nvim",
	ft = { "rust" }, -- Rust開いたときだけロード
	dependencies = {
		"neovim/nvim-lspconfig",
		"nvim-lua/plenary.nvim",
		"folke/which-key.nvim",
	},
	config = function()
		local rt = require("rust-tools")

		rt.setup({
			tools = {
				autoSetHints = true, -- Inlay Hints 自動表示
				hover_with_actions = true, -- Hover + Action
			},
			server = {
				settings = {
					["rust-analyzer"] = {
						cargo = {
							allFeatures = true,
						},
						checkOnSave = {
							command = "clippy", -- 保存時 clippy
						},
					},
				},
				on_attach = function(_, bufnr)
					local wk = require("which-key")

					wk.register({
						["K"] = { vim.lsp.buf.hover, "Hover docs" },
						["gd"] = { vim.lsp.buf.definition, "Go to definition" },
						["gr"] = { vim.lsp.buf.references, "References" },
						["gi"] = { vim.lsp.buf.implementation, "Implementation" },
						["<leader>ca"] = { vim.lsp.buf.code_action, "Code Action" },
						["<leader>rn"] = { vim.lsp.buf.rename, "Rename" },
						["<leader>rr"] = {
							rt.runnables.runnables,
							"Rust Runnables",
						},
						["<leader>rd"] = {
							rt.debuggables.debuggables,
							"Rust Debuggables",
						},
					}, { buffer = bufnr })

					-- Inlay Hints トグル
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
