local M = {}

local namespace = vim.api.nvim_create_namespace("NazoVimScopeContext")
local enabled = true
local states = {}
local scope_names = {
	class = true,
	["function"] = true,
	method = true,
	if_statement = true,
	for_statement = true,
	while_statement = true,
	switch_statement = true,
	impl_item = true,
	loop_expression = true,
}

local function is_scope(node_type)
	if scope_names[node_type] then
		return true
	end
	return node_type:match("function") ~= nil
		or node_type:match("method") ~= nil
		or node_type:match("class") ~= nil
		or node_type:match("loop") ~= nil
end

local function scope_lines(buf, row, col, width)
	local ok, node = pcall(vim.treesitter.get_node, { bufnr = buf, pos = { row, col } })
	if not ok or not node then
		return {}
	end
	local seen, lines = {}, {}
	while node do
		local start_row, _, end_row = node:range()
		if start_row < row and end_row >= row and not seen[start_row] and is_scope(node:type()) then
			local line = vim.api.nvim_buf_get_lines(buf, start_row, start_row + 1, false)[1] or ""
			line = vim.trim(line):gsub("%s+", " ")
			if line ~= "" then
				seen[start_row] = true
				lines[#lines + 1] = { row = start_row, text = line }
			end
		end
		node = node:parent()
	end
	table.sort(lines, function(a, b)
		return a.row < b.row
	end)
	local maximum = math.max(1, math.min(8, tonumber(vim.g.nazovim_scope_context_lines) or 3))
	while #lines > maximum do
		table.remove(lines, 1)
	end
	local result = {}
	for _, entry in ipairs(lines) do
		local text = entry.text
		local available = math.max(1, width - 2)
		if vim.fn.strdisplaywidth(text) > available then
			text = vim.fn.strcharpart(text, 0, available - 1) .. "…"
		end
		result[#result + 1] = text
	end
	return result
end

local function close_float(state)
	if state.float and vim.api.nvim_win_is_valid(state.float) then
		vim.api.nvim_win_close(state.float, true)
	end
	state.float = nil
	if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
		vim.api.nvim_buf_delete(state.buf, { force = true })
	end
	state.buf = nil
end

local function render(win)
	local state = states[win]
	if not state or not enabled or not vim.api.nvim_win_is_valid(win) then
		if state then
			close_float(state)
		end
		return
	end
	local buf = vim.api.nvim_win_get_buf(win)
	if vim.bo[buf].buftype ~= "" then
		close_float(state)
		return
	end
	local cursor = vim.api.nvim_win_get_cursor(win)
	local width = vim.api.nvim_win_get_width(win)
	local lines = scope_lines(buf, cursor[1] - 1, cursor[2], width)
	if #lines == 0 then
		close_float(state)
		return
	end
	if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
		state.buf = vim.api.nvim_create_buf(false, true)
		vim.bo[state.buf].buftype = "nofile"
		vim.bo[state.buf].bufhidden = "wipe"
		vim.bo[state.buf].swapfile = false
		vim.bo[state.buf].modifiable = false
	end
	vim.bo[state.buf].modifiable = true
	vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
	vim.bo[state.buf].modifiable = false
	local config = {
		relative = "win",
		win = win,
		row = 0,
		col = 0,
		width = width,
		height = #lines,
		style = "minimal",
		focusable = false,
		zindex = 40,
		noautocmd = true,
	}
	if state.float and vim.api.nvim_win_is_valid(state.float) then
		vim.api.nvim_win_set_config(state.float, config)
		vim.api.nvim_win_set_buf(state.float, state.buf)
	else
		state.float = vim.api.nvim_open_win(state.buf, false, config)
	end
	vim.wo[state.float].wrap = false
	vim.wo[state.float].number = false
	vim.wo[state.float].relativenumber = false
	vim.wo[state.float].signcolumn = "no"
	vim.wo[state.float].winhighlight = "Normal:NormalFloat"
	vim.api.nvim_buf_clear_namespace(state.buf, namespace, 0, -1)
	for index = 0, #lines - 1 do
		vim.api.nvim_buf_add_highlight(state.buf, namespace, "Comment", index, 0, -1)
	end
end

local function schedule(win)
	if not enabled or not vim.api.nvim_win_is_valid(win) then
		return
	end
	local state = states[win]
	if not state then
		state = { timer = vim.uv.new_timer() }
		states[win] = state
	end
	state.timer:stop()
	state.timer:start(
		60,
		0,
		vim.schedule_wrap(function()
			render(win)
		end)
	)
end

local function dispose(win)
	local state = states[win]
	if not state then
		return
	end
	if state.timer then
		state.timer:stop()
		state.timer:close()
	end
	close_float(state)
	states[win] = nil
end

---Toggle pinned syntax context for the current window.
function M.toggle()
	enabled = not enabled
	if enabled then
		schedule(vim.api.nvim_get_current_win())
	else
		for win in pairs(states) do
			close_float(states[win])
		end
	end
	vim.notify("Pinned context " .. (enabled and "enabled" or "disabled"), vim.log.levels.INFO, { title = "NazoVim" })
end

---Show enclosing syntax scopes at the top of each editor window.
function M.setup()
	enabled = vim.g.nazovim_scope_context_enabled ~= false
	local group = vim.api.nvim_create_augroup("NazoVimScopeContext", { clear = true })
	vim.api.nvim_create_autocmd(
		{ "CursorMoved", "CursorMovedI", "BufEnter", "TextChanged", "TextChangedI", "WinScrolled", "VimResized" },
		{
			group = group,
			callback = function(event)
				if event.event == "VimResized" then
					for win in pairs(states) do
						schedule(win)
					end
				elseif event.event == "WinScrolled" then
					schedule(tonumber(event.match) or vim.api.nvim_get_current_win())
				else
					schedule(vim.api.nvim_get_current_win())
				end
			end,
		}
	)
	vim.api.nvim_create_autocmd("WinClosed", {
		group = group,
		callback = function(event)
			dispose(tonumber(event.match))
		end,
	})
	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = group,
		callback = function()
			for win in pairs(states) do
				dispose(win)
			end
		end,
	})
	vim.api.nvim_create_user_command("NazoScopeContextToggle", M.toggle, { desc = "Toggle pinned syntax context" })
end

return M
