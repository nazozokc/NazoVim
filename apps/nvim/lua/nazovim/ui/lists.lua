local M = {}

local severities = {
	[vim.diagnostic.severity.ERROR] = "E",
	[vim.diagnostic.severity.WARN] = "W",
	[vim.diagnostic.severity.INFO] = "I",
	[vim.diagnostic.severity.HINT] = "N",
}

local function quickfix_open()
	local info = vim.fn.getqflist({ title = 1, winid = 1 })
	return info.winid and info.winid ~= 0, info.title
end

local function toggle_list(title, items)
	local open, current_title = quickfix_open()
	if open and current_title == title then
		vim.cmd.cclose()
		return
	end
	vim.fn.setqflist({}, " ", { title = title, items = items })
	vim.cmd.copen()
end

local function diagnostic_items(buf)
	local diagnostics = vim.diagnostic.get(buf)
	local items = {}
	for _, diagnostic in ipairs(diagnostics) do
		local name = vim.api.nvim_buf_get_name(diagnostic.bufnr or buf or 0)
		if name ~= "" then
			local text = diagnostic.message:gsub("\n", " ")
			if diagnostic.source and diagnostic.source ~= "" then
				text = diagnostic.source .. ": " .. text
			end
			items[#items + 1] = {
				filename = name,
				lnum = diagnostic.lnum + 1,
				col = (diagnostic.col or 0) + 1,
				end_lnum = (diagnostic.end_lnum or diagnostic.lnum) + 1,
				end_col = (diagnostic.end_col or diagnostic.col or 0) + 1,
				text = text,
				type = severities[diagnostic.severity] or "I",
				valid = 1,
			}
		end
	end
	table.sort(items, function(a, b)
		if a.filename ~= b.filename then
			return a.filename < b.filename
		elseif a.lnum ~= b.lnum then
			return a.lnum < b.lnum
		end
		return a.col < b.col
	end)
	return items
end

---Toggle all workspace diagnostics in the quickfix list.
function M.diagnostics()
	toggle_list("NazoVim Diagnostics", diagnostic_items())
end

---Toggle diagnostics belonging to the current buffer.
function M.buffer_diagnostics()
	local buf = vim.api.nvim_get_current_buf()
	toggle_list("NazoVim Buffer Diagnostics", diagnostic_items(buf))
end

---Show document symbols from the active language server in quickfix.
function M.document_symbols()
	local buf = vim.api.nvim_get_current_buf()
	local clients = vim.lsp.get_clients({ bufnr = buf, method = "textDocument/documentSymbol" })
	if #clients == 0 then
		vim.notify("No language server provides document symbols for this buffer", vim.log.levels.INFO, {
			title = "NazoVim Lists",
		})
		return
	end
	vim.lsp.buf.document_symbol({
		on_list = function(options)
			options.title = "NazoVim Document Symbols"
			vim.fn.setqflist({}, " ", options)
			vim.cmd.copen()
		end,
	})
end

---Show language servers currently attached to the active buffer.
function M.lsp_clients()
	local buf = vim.api.nvim_get_current_buf()
	local clients = vim.lsp.get_clients({ bufnr = buf })
	local items = {}
	for _, client in ipairs(clients) do
		local root = client.config.root_dir or "(no root)"
		items[#items + 1] = {
			filename = vim.api.nvim_buf_get_name(buf),
			lnum = 1,
			col = 1,
			text = string.format("%s  —  %s", client.name, root),
			valid = 1,
		}
	end
	table.sort(items, function(a, b)
		return a.text < b.text
	end)
	toggle_list("NazoVim Language Servers", items)
end

---Register standalone quickfix list commands and mappings.
function M.setup()
	vim.api.nvim_create_user_command("NazoDiagnostics", M.diagnostics, { desc = "Toggle workspace diagnostics" })
	vim.api.nvim_create_user_command("NazoBufferDiagnostics", M.buffer_diagnostics, {
		desc = "Toggle current buffer diagnostics",
	})
	vim.api.nvim_create_user_command("NazoDocumentSymbols", M.document_symbols, { desc = "List document symbols" })
	vim.api.nvim_create_user_command("NazoLspClients", M.lsp_clients, { desc = "List attached language servers" })
	vim.keymap.set("n", "<leader>xx", M.diagnostics, { desc = "Workspace diagnostics" })
	vim.keymap.set("n", "<leader>xX", M.buffer_diagnostics, { desc = "Buffer diagnostics" })
	vim.keymap.set("n", "<leader>cs", M.document_symbols, { desc = "Document symbols" })
	vim.keymap.set("n", "<leader>cl", M.lsp_clients, { desc = "Language servers" })
end

return M
