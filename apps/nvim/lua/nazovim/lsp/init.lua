local M = {}

local title = "NazoVim LSP"

---Directories lua_ls reads type definitions from.
---VIMRUNTIME supplies the Neovim API, and the nazoplug runtime directory
---supplies the `NazoSpec` annotations used by the plugin manager.
---@return string[]
local function lua_library()
	local library = { vim.env.VIMRUNTIME }
	local spec = vim.api.nvim_get_runtime_file("lua/nazoplug/spec.lua", false)[1]
	if spec then
		library[#library + 1] = vim.fn.fnamemodify(spec, ":h:h")
	end
	return library
end

---Settings shared by the TypeScript and JavaScript halves of ts_ls.
local typescript_settings = {
	inlayHints = {
		parameterNames = "none",
		variableTypes = false,
		propertyDeclarationTypes = false,
		functionLikeReturnTypes = false,
		enumMemberValues = false,
	},
	preferences = {
		includeInlayParameterNameHints = "none",
		includeInlayFunctionParameterTypeHints = false,
		includeInlayVariableTypeHints = false,
		includeInlayPropertyDeclarationTypeHints = false,
		includeInlayFunctionLikeReturnTypeHints = false,
		includeInlayEnumMemberValueHints = false,
		-- Imports stay portable instead of hard-coding relative paths.
		importModuleSpecifier = "non-relative",
	},
	updateImportsOnFileMove = { enabled = "always" },
}

---Language servers started by NazoVim itself.
---The executables come from PATH (the devShell provides them), so nothing is
---downloaded at runtime and the setup stays reproducible.
local servers = {
	lua_ls = {
		cmd = { "lua-language-server" },
		filetypes = { "lua" },
		root_markers = { ".luarc.json", ".luarc.jsonc", ".stylua.toml", "stylua.toml", ".git" },
		settings = {
			Lua = {
				diagnostics = { globals = { "vim" } },
				-- stylua owns formatting; lua_ls only diagnoses.
				format = { enable = false },
				runtime = { version = "LuaJIT" },
				workspace = {
					checkThirdParty = false,
					library = lua_library(),
				},
			},
		},
	},
	clangd = {
		cmd = { "clangd", "--background-index" },
		filetypes = { "c", "cpp", "objc", "objcpp", "cuda" },
		root_markers = { "compile_commands.json", "compile_flags.txt", ".clangd", ".git" },
		settings = {
			clangd = {
				-- Keep diagnostics useful without a compilation database.
				fallbackFlags = { "-std=c++20" },
			},
		},
	},
	html = {
		cmd = { "vscode-html-language-server", "--stdio" },
		filetypes = { "html" },
		root_markers = { "package.json", ".git" },
	},
	cssls = {
		cmd = { "vscode-css-language-server", "--stdio" },
		filetypes = { "css", "scss", "less" },
		root_markers = { "package.json", ".git" },
	},
	jsonls = {
		cmd = { "vscode-json-language-server", "--stdio" },
		filetypes = { "json", "jsonc" },
		root_markers = { "package.json", ".git" },
	},
	emmet_language_server = {
		cmd = { "emmet-language-server", "--stdio" },
		filetypes = {
			"html",
			"css",
			"scss",
			"javascriptreact",
			"typescriptreact",
			"vue",
			"svelte",
		},
		root_markers = { "package.json", ".git" },
	},
	nixd = {
		cmd = { "nixd" },
		filetypes = { "nix" },
		root_markers = { "flake.nix", "default.nix", ".git" },
	},
	taplo = {
		cmd = { "taplo", "lsp", "stdio" },
		filetypes = { "toml" },
		root_markers = { ".taplo.toml", "taplo.toml", ".git" },
	},
	yamlls = {
		cmd = { "yaml-language-server", "--stdio" },
		filetypes = { "yaml", "yaml.docker-compose" },
		root_markers = { "package.json", ".git" },
	},
	marksman = {
		cmd = { "marksman", "server" },
		filetypes = { "markdown" },
		root_markers = { ".marksman.toml", ".git" },
	},
	bashls = {
		cmd = { "bash-language-server", "start" },
		filetypes = { "sh", "bash" },
		root_markers = { ".git" },
		settings = {
			bashIde = {
				globPattern = "*@(.sh|.inc|.bash|.command)",
			},
		},
	},
	gopls = {
		cmd = { "gopls" },
		filetypes = { "go", "gomod", "gowork", "gotmpl" },
		root_markers = { "go.work", "go.mod", ".git" },
		settings = {
			gopls = {
				usePlaceholders = true,
				analyses = { unusedparams = true },
			},
		},
	},
	pyright = {
		cmd = { "pyright-langserver", "--stdio" },
		filetypes = { "python" },
		root_markers = { "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", ".git" },
		settings = {
			python = {
				analysis = { autoSearchPaths = true, useLibraryCodeForTypes = true },
			},
		},
	},
	jdtls = {
		-- jdtls locks its workspace, so every project root gets its own one.
		binary = "jdtls",
		cmd = function(dispatchers, config)
			local root = (config and config.root_dir) or vim.fn.getcwd()
			local name = vim.fs.basename(root)
			local workspace = table.concat({ vim.fn.stdpath("cache"), "jdtls", name }, "/")
			vim.fn.mkdir(workspace, "p")
			return vim.lsp.rpc.start({ "jdtls", "-data", workspace }, dispatchers, { cwd = root })
		end,
		filetypes = { "java" },
		root_markers = { "pom.xml", "build.gradle", "build.gradle.kts", "settings.gradle", ".git" },
	},
	rust_analyzer = {
		cmd = { "rust-analyzer" },
		filetypes = { "rust" },
		root_markers = { "Cargo.toml", "rust-project.json", ".git" },
		settings = {
			["rust-analyzer"] = {
				cargo = { allFeatures = true },
				check = { command = "clippy" },
			},
		},
	},
	ts_ls = {
		cmd = { "typescript-language-server", "--stdio" },
		filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
		root_markers = { "tsconfig.json", "jsconfig.json", "package.json", ".git" },
		init_options = { hostInfo = "neovim" },
		settings = {
			typescript = typescript_settings,
			javascript = typescript_settings,
		},
	},
	solargraph = {
		cmd = { "solargraph", "stdio" },
		filetypes = { "ruby" },
		root_markers = { "Gemfile", ".git" },
	},
	zls = {
		cmd = { "zls" },
		filetypes = { "zig" },
		root_markers = { "build.zig", "build.zig.zon", ".git" },
		settings = {
			zls = {
				enable_inlay_hints = true,
				enable_snippets = true,
				warn_style = true,
			},
		},
	},
}

---Per-server adjustments applied when a client attaches.
---The listed server capabilities are cleared because another tool owns them.
local overrides = {
	ts_ls = {
		without_capabilities = {
			"documentFormattingProvider",
			"documentRangeFormattingProvider",
			"semanticTokensProvider",
		},
	},
}

---Servers that were enabled because their executable exists.
local enabled = {}

---Return the executable a server definition launches.
---@param server table
---@return string?
function M.binary(server)
	if server.binary then
		return server.binary
	end
	return type(server.cmd) == "table" and server.cmd[1] or nil
end

local function executable(server)
	local binary = M.binary(server)
	return binary ~= nil and vim.fn.executable(binary) == 1
end

---Return the configured server definitions.
function M.servers()
	return servers
end

---Return the per-server attach overrides.
function M.overrides()
	return overrides
end

---Return the servers that were enabled at startup.
function M.enabled()
	return enabled
end

---Return the servers whose executable is missing from PATH.
function M.missing()
	local result = {}
	for name, server in pairs(servers) do
		if not executable(server) then
			result[#result + 1] = name
		end
	end
	table.sort(result)
	return result
end

local function capabilities()
	return vim.tbl_deep_extend(
		"force",
		vim.lsp.protocol.make_client_capabilities(),
		{ textDocument = { completion = { completionItem = { snippetSupport = true } } } }
	)
end

---Give a built-in handler default float options.
---`vim.lsp.with()` is deprecated in 0.12, so the merge happens here.
---@param handler function
---@param config table
---@return function
local function floating(handler, config)
	return function(err, result, ctx, opts)
		handler(err, result, ctx, vim.tbl_deep_extend("force", opts or {}, config))
	end
end

---Build the shell command for a rust-analyzer runnable.
---@param runnable table
---@return string[]
function M.rust_command(runnable)
	local args = runnable.args or {}
	local command = { args.overrideCargo or "cargo" }
	vim.list_extend(command, args.cargoArgs or {})
	if args.executableArgs and #args.executableArgs > 0 then
		command[#command + 1] = "--"
		vim.list_extend(command, args.executableArgs)
	end
	return command
end

---Run a rust-analyzer runnable in a terminal split.
---@param runnable table
function M.rust_run(runnable)
	local args = runnable.args or {}
	local command = M.rust_command(runnable)
	vim.cmd("botright split")
	vim.fn.termopen(command, { cwd = args.workspaceRoot })
end

---Ask rust-analyzer for the runnables at the cursor and run the chosen one.
---@param buffer? integer
function M.rust_runnables(buffer)
	buffer = buffer or vim.api.nvim_get_current_buf()
	local client = vim.lsp.get_clients({ bufnr = buffer, name = "rust_analyzer" })[1]
	if not client then
		vim.notify("rust-analyzer is not attached", vim.log.levels.WARN, { title = title })
		return
	end
	local row, column = unpack(vim.api.nvim_win_get_cursor(0))
	local params = {
		textDocument = vim.lsp.util.make_text_document_params(buffer),
		position = { line = row - 1, character = column },
	}
	client:request("experimental/runnables", params, function(err, result)
		vim.schedule(function()
			if err or not result or #result == 0 then
				vim.notify("No runnables found", vim.log.levels.INFO, { title = title })
				return
			end
			vim.ui.select(result, {
				prompt = "Rust runnables",
				format_item = function(runnable)
					return runnable.label or "runnable"
				end,
			}, function(runnable)
				if runnable then
					M.rust_run(runnable)
				end
			end)
		end)
	end, buffer)
end

---Run a `source.*` code action and apply it.
---@param only string[]
local function source_action(only)
	vim.lsp.buf.code_action({ context = { only = only, diagnostics = {} }, apply = true })
end

---Format the current buffer if format-on-save is enabled.
local function format_on_save(args)
	if vim.g.nazovim_format_on_save == false then
		return
	end
	local clients = vim.lsp.get_clients({ bufnr = args.buf, method = "textDocument/formatting" })
	if #clients == 0 then
		return
	end
	vim.lsp.buf.format({ bufnr = args.buf, async = false, timeout_ms = 1000 })
end

---Restart language servers attached to the current buffer.
function M.restart()
	local buf = vim.api.nvim_get_current_buf()
	local clients = vim.lsp.get_clients({ bufnr = buf })
	if #clients == 0 then
		vim.notify("No LSP clients attached", vim.log.levels.INFO, { title = title })
		return
	end
	for _, client in ipairs(clients) do
		vim.lsp.stop_client(client.id)
	end
	vim.defer_fn(function()
		vim.cmd("edit")
		vim.notify("Restarted " .. #clients .. " LSP client(s)", vim.log.levels.INFO, { title = title })
	end, 100)
end

---Map the shared LSP keymaps plus the server specific actions on a buffer.
---@param buffer integer
---@param client? { name: string }
function M.attach_keymaps(buffer, client)
	local opts = { buffer = buffer }
	local symbols = require("nazovim.lsp.symbols")
	local calls = require("nazovim.lsp.calls")
	local display = require("nazovim.lsp.display")
	local lifecycle = require("nazovim.lsp.lifecycle")

	-- Hover & signature
	vim.keymap.set("n", "K", vim.lsp.buf.hover, vim.tbl_extend("force", opts, { desc = "Hover" }))
	vim.keymap.set(
		"n",
		"<leader>ls",
		vim.lsp.buf.signature_help,
		vim.tbl_extend("force", opts, { desc = "Signature help" })
	)

	-- Navigation
	vim.keymap.set("n", "<leader>ld", vim.lsp.buf.definition, vim.tbl_extend("force", opts, { desc = "Definition" }))
	vim.keymap.set("n", "gD", symbols.declaration, vim.tbl_extend("force", opts, { desc = "Declaration" }))
	vim.keymap.set("n", "<leader>gr", symbols.references, vim.tbl_extend("force", opts, { desc = "References" }))
	vim.keymap.set("n", "grw", symbols.workspace_symbols, vim.tbl_extend("force", opts, { desc = "Workspace symbols" }))
	vim.keymap.set("n", "gO", vim.lsp.buf.document_symbol, vim.tbl_extend("force", opts, { desc = "Document symbols" }))
	vim.keymap.set(
		"n",
		"<leader>lT",
		symbols.type_hierarchy,
		vim.tbl_extend("force", opts, { desc = "Type hierarchy" })
	)
	vim.keymap.set("n", "<leader>lci", function()
		calls.run("incomingCalls")
	end, vim.tbl_extend("force", opts, { desc = "Incoming calls" }))
	vim.keymap.set("n", "<leader>lco", function()
		calls.run("outgoingCalls")
	end, vim.tbl_extend("force", opts, { desc = "Outgoing calls" }))

	-- Refactor / actions
	vim.keymap.set("n", "grn", vim.lsp.buf.rename, vim.tbl_extend("force", opts, { desc = "Rename" }))
	vim.keymap.set(
		{ "n", "x" },
		"gra",
		vim.lsp.buf.code_action,
		vim.tbl_extend("force", opts, { desc = "Code action" })
	)

	-- Formatting
	vim.keymap.set("n", "<leader>lf", function()
		vim.lsp.buf.format({ async = true })
	end, vim.tbl_extend("force", opts, { desc = "Format buffer" }))
	vim.keymap.set("x", "<leader>lF", function()
		vim.lsp.buf.format({ async = true })
	end, vim.tbl_extend("force", opts, { desc = "Format range" }))

	-- General source actions
	vim.keymap.set("n", "<leader>la", function()
		source_action({ "source.organizeImports", "source.fixAll" })
	end, vim.tbl_extend("force", opts, { desc = "Organize / fix all" }))

	-- Server specific
	if client and client.name == "rust_analyzer" then
		vim.keymap.set("n", "<leader>rr", function()
			M.rust_runnables(buffer)
		end, vim.tbl_extend("force", opts, { desc = "Rust runnables" }))
	end
	if client and client.name == "ts_ls" then
		vim.keymap.set("n", "<leader>oi", function()
			source_action({ "source.organizeImports", "source.organizeImports.ts" })
		end, vim.tbl_extend("force", opts, { desc = "Organize imports" }))
		vim.keymap.set("n", "<leader>ru", function()
			source_action({ "source.removeUnused", "source.removeUnused.ts", "source.removeUnusedImports" })
		end, vim.tbl_extend("force", opts, { desc = "Remove unused" }))
	end
end

---Show which servers are enabled, attached, and missing.
function M.info()
	local lines = { "enabled: " .. (#enabled > 0 and table.concat(enabled, ", ") or "none") }
	local attached = {}
	for _, client in ipairs(vim.lsp.get_clients({ bufnr = vim.api.nvim_get_current_buf() })) do
		local root = client.config.root_dir and vim.fs.basename(client.config.root_dir) or "no root"
		attached[#attached + 1] = string.format("%s (%s)", client.name, root)
	end
	if #attached > 0 then
		lines[#lines + 1] = "attached: " .. table.concat(attached, ", ")
	end
	local missing = M.missing()
	if #missing > 0 then
		lines[#lines + 1] = "missing: " .. table.concat(missing, ", ")
	end

	local buf = vim.api.nvim_get_current_buf()
	local attached = vim.lsp.get_clients({ bufnr = buf })
	if #attached > 0 then
		lines[#lines + 1] = "attached:"
		for _, client in ipairs(attached) do
			local root = client.config.root_dir or "?"
			lines[#lines + 1] = string.format("  %s (root: %s)", client.name, root)
		end
	else
		lines[#lines + 1] = "attached: none"
	end

	vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = title })
end

---Apply the per-server capability overrides when a client attaches.
---@param client table
function M.apply_overrides(client)
	local override = overrides[client.name]
	if not override then
		return
	end
	for _, capability in ipairs(override.without_capabilities or {}) do
		client.server_capabilities[capability] = false
	end
end

---Register the server definitions, enable the available ones and map the
---shared LSP buffer keymaps.
function M.setup()
	local caps = capabilities()
	local start = {}
	for name, server in pairs(servers) do
		local definition = vim.deepcopy(server)
		-- `binary` is a NazoVim helper; vim.lsp.config rejects unknown fields.
		definition.binary = nil
		vim.lsp.config(name, vim.tbl_extend("force", { capabilities = caps }, definition))
		if executable(server) then
			start[#start + 1] = name
		end
	end
	table.sort(start)
	enabled = start

	local group = vim.api.nvim_create_augroup("NazoLsp", { clear = true })

	vim.api.nvim_create_autocmd("LspAttach", {
		group = group,
		desc = "Apply the NazoVim LSP buffer keymaps",
		callback = function(args)
			local client_id = args.data and args.data.client_id
			local client = client_id and vim.lsp.get_client_by_id(client_id) or nil
			if client then
				M.apply_overrides(client)
			end
			M.attach_keymaps(args.buf, client)
		end,
	})

	vim.api.nvim_create_autocmd("BufWritePre", {
		group = group,
		desc = "Format on save when enabled",
		callback = format_on_save,
	})

	vim.api.nvim_create_autocmd("LspDetach", {
		group = group,
		desc = "Notify when an LSP client detaches",
		callback = function(args)
			local client = vim.lsp.get_client_by_id(args.data.client_id)
			if client then
				vim.notify(client.name .. " detached", vim.log.levels.INFO, { title = title })
			end
		end,
	})

	if #start > 0 then
		vim.lsp.enable(start)
	end

	vim.api.nvim_create_user_command("NazoLspInfo", M.info, { desc = "Show the enabled language servers" })
	vim.api.nvim_create_user_command("NazoLspRestart", M.restart, { desc = "Restart LSP clients for the current buffer" })
end

return M
