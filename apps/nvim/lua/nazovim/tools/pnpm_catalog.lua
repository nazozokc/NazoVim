local M = {}

local diagnostics_ns = vim.api.nvim_create_namespace("NazoVimPnpmCatalogDiagnostics")
local overlay_ns = vim.api.nvim_create_namespace("NazoVimPnpmCatalogOverlay")
local enabled = true
local pending = {}

local function unquote(value)
	value = vim.trim(value or "")
	value = value:gsub("%s+#.*$", "")
	if (value:sub(1, 1) == '"' and value:sub(-1) == '"') or (value:sub(1, 1) == "'" and value:sub(-1) == "'") then
		value = value:sub(2, -2)
	end
	return value
end

local function parse_workspace(path)
	local catalogs = { default = {} }
	local ok, lines = pcall(vim.fn.readfile, path)
	if not ok then
		return catalogs
	end
	local section, current = nil, "default"
	for _, line in ipairs(lines) do
		local indent = #(line:match("^(%s*)") or "")
		local text = vim.trim(line)
		if text == "catalog:" and indent == 0 then
			section, current = "default", "default"
		elseif text == "catalogs:" and indent == 0 then
			section, current = "named", nil
		elseif indent == 0 and text ~= "" and not text:match("^#") then
			section, current = nil, nil
		elseif section == "default" and indent >= 2 then
			local name, version = text:match("^([^:]+):%s*(.-)%s*$")
			if name and version and version ~= "" then
				catalogs.default[unquote(name)] = unquote(version)
			end
		elseif section == "named" and indent == 2 then
			local name = text:match("^([%w_.%-]+):%s*$")
			if name then
				current = name
				catalogs[current] = catalogs[current] or {}
			end
		elseif section == "named" and indent >= 4 and current then
			local name, version = text:match("^([^:]+):%s*(.-)%s*$")
			if name and version and version ~= "" then
				catalogs[current][unquote(name)] = unquote(version)
			end
		end
	end
	return catalogs
end

local function package_root(buf)
	local root = vim.fs.root(buf, { "pnpm-workspace.yaml" })
	if root then
		return root
	end
	return nil
end

local function catalog_specifier(specifier)
	local name = specifier:match("^catalog:(.*)$")
	if name == nil then
		return nil
	end
	return name == "" and "default" or name
end

local function locate_spec(lines, package, specifier)
	local encoded_package = vim.json.encode(package)
	local encoded_specifier = vim.json.encode(specifier)
	for row, line in ipairs(lines) do
		local key_start = line:find(encoded_package, 1, true)
		if key_start then
			local value_start = line:find(encoded_specifier, key_start + #encoded_package, true)
			if value_start then
				return row - 1, value_start - 1, value_start + #encoded_specifier - 1
			end
		end
	end
	return nil
end

local function catalog_entries(buf, catalogs)
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local decoded_ok, package_json = pcall(vim.json.decode, table.concat(lines, "\n"))
	if not decoded_ok or type(package_json) ~= "table" then
		return {}, {}
	end
	local entries, diagnostics = {}, {}
	for _, section in ipairs({ "dependencies", "devDependencies", "peerDependencies", "optionalDependencies" }) do
		local dependencies = package_json[section]
		if type(dependencies) == "table" then
			for package, specifier in pairs(dependencies) do
				if type(package) == "string" and type(specifier) == "string" then
					local catalog_name = catalog_specifier(specifier)
					if catalog_name then
						local row, start_col, end_col = locate_spec(lines, package, specifier)
						if row then
							local version = catalogs[catalog_name] and catalogs[catalog_name][package]
							local message = version and ("PNPM catalog: " .. version)
								or ("Unknown PNPM catalog entry: " .. catalog_name .. "/" .. package)
							entries[#entries + 1] = {
								row = row,
								start_col = start_col,
								end_col = end_col,
								version = version,
								message = message,
							}
							diagnostics[#diagnostics + 1] = {
								lnum = row,
								col = start_col,
								end_lnum = row,
								end_col = end_col,
								severity = version and vim.diagnostic.severity.HINT or vim.diagnostic.severity.WARN,
								message = message,
								source = "NazoVim PNPM catalog",
							}
						end
					end
				end
			end
		end
	end
	return entries, diagnostics
end

local function display_mode()
	local mode = vim.g.pnpm_catalog_display or vim.g.nazovim_pnpm_catalog_display or "diagnostics"
	return mode == "overlay" and "overlay" or "diagnostics"
end

local function render(buf)
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	vim.api.nvim_buf_clear_namespace(buf, overlay_ns, 0, -1)
	if not enabled or vim.bo[buf].filetype ~= "json" then
		vim.diagnostic.set(diagnostics_ns, buf, {})
		return
	end
	local root = package_root(buf)
	if not root then
		vim.diagnostic.set(diagnostics_ns, buf, {})
		return
	end
	local path = root .. "/pnpm-workspace.yaml"
	if vim.fn.filereadable(path) ~= 1 then
		vim.diagnostic.set(diagnostics_ns, buf, {})
		return
	end
	local catalogs = parse_workspace(path)
	local entries, diagnostics = catalog_entries(buf, catalogs)
	local mode = display_mode()
	if mode == "overlay" then
		vim.diagnostic.set(diagnostics_ns, buf, {})
		for _, entry in ipairs(entries) do
			local text = entry.version and ("  " .. entry.version) or ("  ? " .. entry.message)
			vim.api.nvim_buf_set_extmark(buf, overlay_ns, entry.row, entry.start_col, {
				virt_text = { { text, entry.version and "DiagnosticHint" or "DiagnosticWarn" } },
				virt_text_pos = "overlay",
				priority = 110,
			})
		end
	else
		vim.diagnostic.set(diagnostics_ns, buf, diagnostics)
	end
end

local function schedule(buf)
	if pending[buf] then
		return
	end
	pending[buf] = true
	vim.defer_fn(function()
		pending[buf] = nil
		if vim.api.nvim_buf_is_valid(buf) then
			render(buf)
		end
	end, 100)
end

---Enable PNPM catalog version hints.
function M.enable()
	enabled = true
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == "json" then
			schedule(buf)
		end
	end
end

---Disable PNPM catalog version hints and clear decorations.
function M.disable()
	enabled = false
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_buf_clear_namespace(buf, overlay_ns, 0, -1)
			vim.diagnostic.set(diagnostics_ns, buf, {})
		end
	end
end

---Attach version hints to package.json buffers in PNPM workspaces.
function M.setup()
	enabled = vim.g.nazovim_pnpm_catalog_enabled ~= false
	local group = vim.api.nvim_create_augroup("NazoVimPnpmCatalog", { clear = true })
	vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "TextChanged", "TextChangedI" }, {
		group = group,
		pattern = "*.json",
		callback = function(event)
			schedule(event.buf)
		end,
	})
	vim.api.nvim_create_autocmd("FileType", {
		group = group,
		pattern = "json",
		callback = function(event)
			schedule(event.buf)
		end,
	})
	vim.api.nvim_create_user_command("PnpmCatalogLensEnable", M.enable, { desc = "Enable PNPM catalog hints" })
	vim.api.nvim_create_user_command("PnpmCatalogLensDisable", M.disable, { desc = "Disable PNPM catalog hints" })
end

return M
