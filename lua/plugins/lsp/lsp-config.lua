return {
	{
		"williamboman/mason.nvim",
		event = "VeryLazy",
		opts = {},
	},
	{
		"williamboman/mason-lspconfig.nvim",
		event = "VeryLazy",
		dependencies = { "williamboman/mason.nvim" },
	opts = {
		-- mason が管理するもの（自動インストール対象）
		-- nixd は mason 非対応のため手動インストールが必要（nix 環境では devShell が提供）
		ensure_installed = {
			"html",
			"lua_ls",
			"solargraph",
			"efm",
			"clangd",
	},
	},
	},
	{
		"neovim/nvim-lspconfig",
		lazy = false,
		event = "BufReadPre",
		dependencies = {
			"williamboman/mason.nvim",
			"williamboman/mason-lspconfig.nvim",
		},
		config = function()
			local capabilities = require("cmp_nvim_lsp").default_capabilities()

			-- ===== 共通 on_attach =====
			vim.api.nvim_create_autocmd("LspAttach", {
				callback = function(args)
					local client = vim.lsp.get_client_by_id(args.data.client_id)
					local bufnr = args.buf
					-- ts_ls の semanticTokens を無効化（重い）
					if client and client.name == "ts_ls" then
						client.server_capabilities.semanticTokensProvider = nil
					end
					local opts = { buffer = bufnr }
					vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
					vim.keymap.set("n", "<leader>gd", vim.lsp.buf.definition, opts)
					vim.keymap.set("n", "<leader>gr", vim.lsp.buf.references, opts)
				end,
			})

			-- ===== HTML =====
			vim.lsp.config("html", { capabilities = capabilities })

			-- ===== Lua =====
			vim.lsp.config("lua_ls", {
				capabilities = capabilities,
				settings = {
					Lua = {
						diagnostics = { globals = { "vim" } },
					},
				},
			})

			-- ===== Ruby =====
			vim.lsp.config("solargraph", { capabilities = capabilities })

			-- ts_ls は typescript-tools.nvim が担当するため除外

			-- ===== Nix (mason 非対応のため手動管理) =====
			vim.lsp.config("nixd", { capabilities = capabilities })

			-- ===== EFM =====
			vim.lsp.config("efm", { capabilities = capabilities })

			-- ===== C/C++ =====
			vim.lsp.config("clangd", { capabilities = capabilities })

			-- ===== Java =====
			vim.lsp.config("jdtls", {
				capabilities = capabilities,
				cmd = { "jdtls" },
				root_dir = vim.fs.root(0, { ".git", "mvnw", "gradlew", "pom.xml", "build.gradle" }),
			})

			-- ===== 有効化 =====
			-- ts_ls は typescript-tools.nvim が担当
			-- jdtls は nvim-java が管理するため除外
			-- nixd は mason 非対応（nix devShell または手動インストール）
			vim.lsp.enable({
				"html",
				"lua_ls",
				"solargraph",
				"efm",
				"clangd",
				"nixd",
			})
		end,
	},
}
