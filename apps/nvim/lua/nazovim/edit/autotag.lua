local M = {}

local enabled = true
local supported_filetypes = {
	html = true,
	javascriptreact = true,
	typescriptreact = true,
	jsx = true,
	tsx = true,
	vue = true,
	svelte = true,
	astro = true,
}
local opening_nodes = {
	start_tag = true,
	jsx_opening_element = true,
	element_opening_tag = true,
}
local closing_nodes = {
	end_tag = true,
	jsx_closing_element = true,
	element_closing_tag = true,
}
local element_nodes = {
	element = true,
	jsx_element = true,
	svelte_element = true,
}
local void_elements = {
	area = true,
	base = true,
	br = true,
	col = true,
	embed = true,
	hr = true,
	img = true,
	input = true,
	link = true,
	meta = true,
	param = true,
	source = true,
	track = true,
	wbr = true,
}

local function syntax_node(buf, row, col)
	local ok, node = pcall(vim.treesitter.get_node, { bufnr = buf, pos = { row, col } })
	if ok then
		return node
	end
end

local function tag_node(buf, row, col)
	local node = syntax_node(buf, row, col)
	while node do
		local kind = node:type()
		if opening_nodes[kind] or closing_nodes[kind] then
			return node
		end
		node = node:parent()
	end
end

local function tag_name(node, buf)
	if not node then
		return nil
	end
	local text = vim.treesitter.get_node_text(node, buf)
	local name = text:match("^<%s*/?%s*([%w:_%.%-]+)")
	return name, text
end

local function sibling_tag(element, buf, choices)
	for child in element:iter_children() do
		if choices[child:type()] then
			return child, tag_name(child, buf)
		end
	end
end

local function paired_element(node)
	local parent = node:parent()
	while parent do
		if element_nodes[parent:type()] then
			return parent
		end
		parent = parent:parent()
	end
end

local function rename_close_tag(buf, row, col)
	local opening = tag_node(buf, row, math.max(0, col - 1))
	if not opening or not opening_nodes[opening:type()] then
		return
	end
	local name = tag_name(opening, buf)
	if not name then
		return
	end
	local start_row, start_col = opening:range()
	local open_name_start = start_col + 1
	if row ~= start_row or col < open_name_start or col > open_name_start + #name then
		return
	end
	local element = paired_element(opening)
	if not element then
		return
	end
	local closing, closing_name = sibling_tag(element, buf, closing_nodes)
	if not closing or not closing_name or closing_name == name then
		return
	end
	local close_row, close_col = closing:range()
	vim.api.nvim_buf_set_text(buf, close_row, close_col + 2, close_row, close_col + 2 + #closing_name, { name })
end

local function close_tag(buf, row, cursor_col)
	if cursor_col == 0 then
		return
	end
	local node = tag_node(buf, row, cursor_col - 1)
	if not node or not opening_nodes[node:type()] then
		return
	end
	local name, text = tag_name(node, buf)
	if not name or void_elements[name:lower()] or text:match("/%s*>$") then
		return
	end
	local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
	if line:sub(cursor_col + 1):match("^%s*</") then
		return
	end
	vim.api.nvim_buf_set_text(buf, row, cursor_col, row, cursor_col, { "</" .. name .. ">" })
	if vim.api.nvim_get_current_buf() == buf then
		vim.api.nvim_win_set_cursor(0, { row + 1, cursor_col })
	end
end

---Toggle syntax-aware automatic closing and paired-tag renaming.
function M.toggle()
	enabled = not enabled
	vim.notify("Tag editing " .. (enabled and "enabled" or "disabled"), vim.log.levels.INFO, { title = "NazoVim" })
end

---Register syntax-aware tag closing and paired-tag renaming.
function M.setup()
	enabled = vim.g.nazovim_autotag_enabled ~= false
	local group = vim.api.nvim_create_augroup("NazoAutotag", { clear = true })
	vim.api.nvim_create_autocmd("InsertCharPre", {
		group = group,
		callback = function(event)
			if not enabled or vim.v.char ~= ">" or not supported_filetypes[vim.bo[event.buf].filetype] then
				return
			end
			local win = vim.api.nvim_get_current_win()
			local cursor = vim.api.nvim_win_get_cursor(win)
			local row, col = cursor[1] - 1, cursor[2]
			vim.schedule(function()
				if enabled and vim.api.nvim_buf_is_valid(event.buf) and vim.api.nvim_win_is_valid(win) then
					local current = vim.api.nvim_win_get_cursor(win)
					if
						vim.api.nvim_win_get_buf(win) == event.buf
						and current[1] - 1 == row
						and current[2] == col + 1
					then
						close_tag(event.buf, row, current[2])
					end
				end
			end)
		end,
	})
	vim.api.nvim_create_autocmd("TextChangedI", {
		group = group,
		callback = function(event)
			if not enabled or not supported_filetypes[vim.bo[event.buf].filetype] then
				return
			end
			local cursor = vim.api.nvim_win_get_cursor(0)
			rename_close_tag(event.buf, cursor[1] - 1, cursor[2])
		end,
	})
	vim.api.nvim_create_user_command("NazoAutotagToggle", M.toggle, { desc = "Toggle automatic tag editing" })
end

return M
