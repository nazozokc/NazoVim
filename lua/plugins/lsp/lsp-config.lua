return {
	{
		"williamboman/mason.nvim",
		cmd = { "Mason", "MasonInstall", "MasonUninstall", "MasonUpdate", "MasonLog" },
		opts = {},
	},
	{
		"williamboman/mason-lspconfig.nvim",
		lazy = true,
		dependencies = { "williamboman/mason.nvim" },
		opts = {
			ensure_installed = {
				"html",
				"lua_ls",
				"solargraph",
				"efm",
				"clangd",
			},
			automatic_enable = true,
		},
	},
	{
		"neovim/nvim-lspconfig",
		event = "BufReadPre",
		dependencies = {
			"williamboman/mason.nvim",
			"williamboman/mason-lspconfig.nvim",
		},
		config = function()
			local ok, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
			local capabilities = ok and cmp_nvim_lsp.default_capabilities()
				or vim.lsp.protocol.make_client_capabilities()

			vim.api.nvim_create_autocmd("LspAttach", {
				callback = function(args)
					local client = vim.lsp.get_client_by_id(args.data.client_id)
					local bufnr = args.buf
					if client and client.name == "ts_ls" then
						client.server_capabilities.semanticTokensProvider = nil
					end
					local opts = { buffer = bufnr }
					vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
					vim.keymap.set("n", "<leader>gd", vim.lsp.buf.definition, opts)
					vim.keymap.set("n", "<leader>gr", vim.lsp.buf.references, opts)
				end,
			})

			vim.lsp.config("html", { capabilities = capabilities })

			vim.lsp.config("lua_ls", {
				capabilities = capabilities,
				settings = {
					Lua = {
						diagnostics = { globals = { "vim" } },
					},
				},
			})

			vim.lsp.config("solargraph", { capabilities = capabilities })

			vim.lsp.config("nixd", { capabilities = capabilities })

			vim.lsp.config("efm", { capabilities = capabilities })

			vim.lsp.config("clangd", { capabilities = capabilities })

			vim.lsp.config("jdtls", {
				capabilities = capabilities,
				cmd = { "jdtls" },
				root_dir = vim.fs.root(0, { ".git", "mvnw", "gradlew", "pom.xml", "build.gradle" }),
			})

			vim.lsp.enable({ "nixd" })
		end,
	},
}
