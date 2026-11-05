local M = {}

local state = { win = nil, buf = nil, source_buf = nil, source_win = nil, items = {} }
local generation = {}

local symbol_names = {
	[1] = "File",
	[2] = "Module",
	[3] = "Namespace",
	[4] = "Package",
	[5] = "Class",
	[6] = "Method",
	[7] = "Property",
	[8] = "Field",
	[9] = "Constructor",
	[10] = "Enum",
	[11] = "Interface",
	[12] = "Function",
	[13] = "Variable",
	[14] = "Constant",
	[15] = "String",
	[16] = "Number",
	[17] = "Boolean",
	[18] = "Array",
	[19] = "Object",
	[20] = "Key",
	[21] = "Null",
	[22] = "Enum member",
	[23] = "Struct",
	[24] = "Event",
	[25] = "Operator",
	[26] = "Type parameter",
}

local function source_name(buf)
	local name = vim.api.nvim_buf_get_name(buf)
	return name == "" and "[No Name]" or vim.fn.fnamemodify(name, ":~:.")
end

local function lsp_symbols(buf, callback)
	local clients = vim.lsp.get_clients({ bufnr = buf, method = "textDocument/documentSymbol" })
	if #clients == 0 then
		callback(nil)
		return
	end
	local client = clients[1]
	local params = { textDocument = vim.lsp.util.make_text_document_params(buf) }
	local completed = false
	local ok, requested = pcall(client.request, client, "textDocument/documentSymbol", params, function(err, result)
		if completed then
			return
		end
		completed = true
		if err or type(result) ~= "table" then
			callback(nil)
			return
		end
		local items = {}
		local uri = vim.uri_from_bufnr(buf)
		local function flatten(symbols, depth)
			for _, symbol in ipairs(symbols) do
				local location = symbol.location
				local range = location and location.range or symbol.selectionRange or symbol.range
				if range and range.start then
					items[#items + 1] = {
						name = symbol.name or "(unnamed)",
						kind = symbol_names[symbol.kind] or "Symbol",
						depth = depth,
						location = location or { uri = uri, range = range },
					}
				end
				if symbol.children then
					flatten(symbol.children, depth + 1)
				end
			end
		end
		flatten(result, 0)
		callback(#items > 0 and items or nil)
	end, buf)
	if (not ok or not requested) and not completed then
		completed = true
		callback(nil)
	end
end

local function markdown_symbols(buf)
	if vim.bo[buf].filetype ~= "markdown" and vim.bo[buf].filetype ~= "rmd" then
		return nil
	end
	local items = {}
	for row, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
		local hashes, title = line:match("^(#+)%s+(.+)$")
		if hashes then
			items[#items + 1] = { name = title, kind = "Heading", depth = #hashes - 1, row = row - 1, col = 0 }
		end
	end
	return #items > 0 and items or nil
end

local function treesitter_symbols(buf)
	local ok, parser = pcall(vim.treesitter.get_parser, buf)
	if not ok or not parser then
		return nil
	end
	local parsed, trees = pcall(parser.parse, parser)
	if not parsed or not trees or not trees[1] then
		return nil
	end
	local items, seen = {}, {}
	local function visit(node, depth)
		local kind = node:type()
		local lower = kind:lower()
		local is_symbol = lower:match("function")
			or lower:match("method")
			or lower:match("class")
			or lower:match("interface")
			or lower:match("struct")
			or lower:match("enum")
			or lower:match("namespace")
			or lower:match("module")
			or lower:match("impl_item")
		local child_depth = depth
		if is_symbol then
			local row = node:range()
			local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
			line = line and vim.trim(line):gsub("%s+", " ") or ""
			local key = row .. ":" .. line
			if line ~= "" and not seen[key] then
				seen[key] = true
				items[#items + 1] = { name = line, kind = kind, depth = depth, row = row, col = 0 }
			end
			child_depth = depth + 1
		end
		for child in node:iter_children() do
			visit(child, child_depth)
		end
	end
	visit(trees[1]:root(), 0)
	return #items > 0 and items or nil
end

local function get_items(buf, callback)
	local current_generation = (generation[buf] or 0) + 1
	generation[buf] = current_generation
	lsp_symbols(buf, function(items)
		if generation[buf] ~= current_generation then
			return
		end
		items = items or markdown_symbols(buf) or treesitter_symbols(buf) or {}
		callback(items)
	end)
end

local function render(items)
	if not (state.buf and vim.api.nvim_buf_is_valid(state.buf)) then
		return
	end
	state.items = items
	local lines = {}
	if #items == 0 then
		lines[1] = "No symbols found"
	else
		for _, item in ipairs(items) do
			lines[#lines + 1] = string.rep("  ", math.min(item.depth or 0, 12))
				.. (item.kind or "Symbol")
				.. "  "
				.. (item.name or "(unnamed)")
		end
	end
	vim.bo[state.buf].modifiable = true
	vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
	vim.bo[state.buf].modifiable = false
	if state.win and vim.api.nvim_win_is_valid(state.win) then
		vim.api.nvim_win_set_cursor(state.win, { 1, 0 })
	end
end

local function refresh()
	if not state.win or not vim.api.nvim_win_is_valid(state.win) or not vim.api.nvim_buf_is_valid(state.source_buf) then
		return
	end
	local buf = state.source_buf
	get_items(buf, function(items)
		if state.source_buf == buf then
			render(items)
		end
	end)
end

local function jump_to_item()
	local row = vim.api.nvim_win_get_cursor(0)[1]
	local item = state.items[row]
	if not item then
		return
	end
	if state.source_win and vim.api.nvim_win_is_valid(state.source_win) then
		vim.api.nvim_set_current_win(state.source_win)
	end
	if item.location then
		local clients = vim.lsp.get_clients({ bufnr = state.source_buf, method = "textDocument/documentSymbol" })
		local encoding = clients[1] and clients[1].offset_encoding or "utf-16"
		vim.lsp.util.jump_to_location(item.location, encoding, true)
	elseif vim.api.nvim_buf_is_valid(state.source_buf) then
		vim.api.nvim_win_set_buf(0, state.source_buf)
		vim.api.nvim_win_set_cursor(0, { item.row + 1, item.col or 0 })
	end
end

---Close the current symbol outline window.
function M.close()
	if state.win and vim.api.nvim_win_is_valid(state.win) then
		vim.api.nvim_win_close(state.win, true)
	end
	state.win, state.buf, state.source_buf, state.source_win = nil, nil, nil, nil
	state.items = {}
end

---Open or close a right-side symbol outline for the current buffer.
function M.toggle()
	if state.win and vim.api.nvim_win_is_valid(state.win) then
		M.close()
		return
	end
	state.source_win = vim.api.nvim_get_current_win()
	state.source_buf = vim.api.nvim_get_current_buf()
	state.buf = vim.api.nvim_create_buf(false, true)
	vim.bo[state.buf].buftype = "nofile"
	vim.bo[state.buf].bufhidden = "wipe"
	vim.bo[state.buf].filetype = "nazovim-outline"
	vim.cmd("botright vsplit")
	state.win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(state.win, state.buf)
	local width = math.max(1, math.min(42, math.floor(vim.o.columns * 0.35), math.max(1, vim.o.columns - 20)))
	vim.api.nvim_win_set_width(state.win, width)
	vim.wo[state.win].winfixwidth = true
	vim.wo[state.win].statusline = " NazoVim Outline: " .. source_name(state.source_buf):gsub("%%", "%%%%")
	vim.wo[state.win].cursorline = true
	vim.wo[state.win].wrap = false
	vim.keymap.set("n", "<CR>", jump_to_item, { buffer = state.buf, silent = true, desc = "Jump to symbol" })
	vim.keymap.set("n", "q", M.close, { buffer = state.buf, nowait = true, silent = true, desc = "Close outline" })
	vim.keymap.set("n", "<Esc>", M.close, { buffer = state.buf, nowait = true, silent = true, desc = "Close outline" })
	refresh()
end

---Register the outline command, toggle key, and automatic symbol refresh.
function M.setup()
	local group = vim.api.nvim_create_augroup("NazoVimOutline", { clear = true })
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "BufEnter", "LspAttach" }, {
		group = group,
		callback = function(event)
			if state.win and state.source_buf == event.buf then
				refresh()
			end
		end,
	})
	vim.api.nvim_create_autocmd("WinClosed", {
		group = group,
		callback = function(event)
			if tonumber(event.match) == state.win then
				state.win, state.buf, state.source_buf, state.source_win = nil, nil, nil, nil
				state.items = {}
			end
		end,
	})
	vim.api.nvim_create_user_command("NazoOutlineToggle", M.toggle, { desc = "Toggle document outline" })
	vim.keymap.set("n", "<leader>so", M.toggle, { desc = "Toggle document outline" })
end

return M
