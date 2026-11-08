local M = {}

---Report the language server setup to `:checkhealth nazovim`.
function M.check()
	local health = vim.health
	local lsp = require("nazovim.lsp")

	health.start("NazoVim")
	health.ok("Neovim " .. tostring(vim.version()))

	health.start("NazoVim LSP")
	local enabled = lsp.enabled()
	if #enabled == 0 then
		health.warn("No language server executable was found on PATH")
	else
		health.ok("Enabled: " .. table.concat(enabled, ", "))
	end
	local missing = lsp.missing()
	if #missing > 0 then
		health.warn("Missing executables: " .. table.concat(missing, ", ") .. " — run inside `nix develop`")
	else
		health.ok("Every configured server executable is on PATH")
	end

	local clients = vim.lsp.get_clients()
	if #clients == 0 then
		health.info("No language server is running")
	else
		for _, client in ipairs(clients) do
			health.info(
				string.format(
					"%s (id %d, root %s, %d buffer(s))",
					client.name,
					client.id,
					client.config.root_dir or "none",
					vim.tbl_count(client.attached_buffers or {})
				)
			)
		end
	end

	health.start("NazoVim Treesitter")
	local parsers = vim.api.nvim_get_runtime_file("parser/*.so", true)
	if #parsers == 0 then
		health.warn("No Tree-sitter parser found; set NAZOVIM_TREESITTER_DIR or install grammars")
	else
		health.ok(string.format("%d parser(s) on runtimepath", #parsers))
	end
end

---`nazovim/features.lua` scans every module, so health exposes a no-op setup.
function M.setup() end

return M
