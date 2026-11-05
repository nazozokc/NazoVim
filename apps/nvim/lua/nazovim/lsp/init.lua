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
	},
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
				workspace = {
					checkThirdParty = false,
					library = lua_library(),
				},
			},
		},
	},
	clangd = {
		cmd = { "clangd" },
		filetypes = { "c", "cpp", "objc", "objcpp", "cuda" },
		root_markers = { "compile_commands.json", "compile_flags.txt", ".clangd", ".git" },
	},
	html = {
		cmd = { "vscode-html-language-server", "--stdio" },
		filetypes = { "html" },
		root_markers = { "package.json", ".git" },
	},
	nixd = {
		cmd = { "nixd" },
		filetypes = { "nix" },
		root_markers = { "flake.nix", "default.nix", ".git" },
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

---Map the shared LSP keymaps plus the server specific actions on a buffer.
---@param buffer integer
---@param client? { name: string }
function M.attach_keymaps(buffer, client)
	local opts = { buffer = buffer }
	vim.keymap.set("n", "K", vim.lsp.buf.hover, vim.tbl_extend("force", opts, { desc = "Hover" }))
	vim.keymap.set(
		"n",
		"<leader>ls",
		vim.lsp.buf.signature_help,
		vim.tbl_extend("force", opts, { desc = "Signature help" })
	)
	vim.keymap.set("n", "<leader>ld", vim.lsp.buf.definition, vim.tbl_extend("force", opts, { desc = "Definition" }))
	vim.keymap.set("n", "<leader>gr", vim.lsp.buf.references, vim.tbl_extend("force", opts, { desc = "References" }))
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

---Show which servers are enabled and which executables are missing.
function M.info()
	local lines = { "enabled: " .. (#enabled > 0 and table.concat(enabled, ", ") or "none") }
	local missing = M.missing()
	if #missing > 0 then
		lines[#lines + 1] = "missing: " .. table.concat(missing, ", ")
	end
	vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = title })
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

	vim.api.nvim_create_autocmd("LspAttach", {
		group = vim.api.nvim_create_augroup("NazoLsp", { clear = true }),
		desc = "Apply the NazoVim LSP buffer keymaps",
		callback = function(args)
			local client_id = args.data and args.data.client_id
			local client = client_id and vim.lsp.get_client_by_id(client_id) or nil
			if client and client.name == "ts_ls" then
				-- Prettier handles formatting and the semantic tokens are noisy.
				client.server_capabilities.documentFormattingProvider = false
				client.server_capabilities.documentRangeFormattingProvider = false
				client.server_capabilities.semanticTokensProvider = nil
			end
			M.attach_keymaps(args.buf, client)
		end,
	})

	if #start > 0 then
		vim.lsp.enable(start)
	end

	vim.api.nvim_create_user_command("NazoLspInfo", M.info, { desc = "Show the enabled language servers" })
end

return M
