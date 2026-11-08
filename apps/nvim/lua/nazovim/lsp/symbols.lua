local M = {}

local title = "NazoVim LSP"

local function notify(message, level)
	vim.notify(message, level or vim.log.levels.INFO, { title = title })
end

---Whether a client attached to the buffer can answer `method`.
---@param buf integer
---@param method string
---@return boolean
local function supported(buf, method)
	return #vim.lsp.get_clients({ bufnr = buf, method = method }) > 0
end

---Pick a workspace symbol and show the matches in the quickfix list.
function M.workspace_symbols()
	local buf = vim.api.nvim_get_current_buf()
	if not supported(buf, "workspace/symbol") then
		notify("No language server provides workspace symbols for this buffer", vim.log.levels.WARN)
		return
	end
	vim.ui.input({ prompt = "Workspace symbol: " }, function(query)
		if query == nil then
			return
		end
		vim.lsp.buf.workspace_symbol(query, {
			on_list = function(options)
				require("nazovim.ui.lists").set(options.title or "Workspace Symbols", options.items or {})
			end,
		})
	end)
end

---Show the references at the cursor in the quickfix list.
function M.references()
	if not supported(vim.api.nvim_get_current_buf(), "textDocument/references") then
		notify("No language server provides references for this buffer", vim.log.levels.WARN)
		return
	end
	vim.lsp.buf.references(nil, {
		on_list = function(options)
			local items = options.items or {}
			if #items == 0 then
				notify("No references found")
				return
			end
			require("nazovim.ui.lists").set("NazoVim References", items)
		end,
	})
end

---Jump to the declaration of the symbol under the cursor.
function M.declaration()
	vim.lsp.buf.declaration()
end

---Choose between supertypes and subtypes of the symbol under the cursor.
function M.type_hierarchy()
	local buf = vim.api.nvim_get_current_buf()
	if not supported(buf, "textDocument/prepareTypeHierarchy") then
		notify("No language server provides type hierarchies for this buffer", vim.log.levels.WARN)
		return
	end
	vim.ui.select({ "supertypes", "subtypes" }, { prompt = "Type hierarchy" }, function(kind)
		if kind then
			vim.lsp.buf.typehierarchy(kind)
		end
	end)
end

---Register the commands that are not tied to a buffer.
function M.setup()
	vim.api.nvim_create_user_command("NazoLspSymbols", M.workspace_symbols, {
		desc = "Search workspace symbols",
	})
	vim.api.nvim_create_user_command("NazoLspReferences", M.references, {
		desc = "List references in the quickfix list",
	})
end

return M
