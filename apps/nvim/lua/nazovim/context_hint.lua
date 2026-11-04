local M = {}

local namespace = vim.api.nvim_create_namespace("NazoVimContextHint")
local enabled = true
local timers = {}
local last = {}
local prefix = "↳ "

local scope_types = {
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
	if scope_types[node_type] then
		return true
	end
	return node_type:match("function") ~= nil
		or node_type:match("method") ~= nil
		or node_type:match("class") ~= nil
		or node_type:match("loop") ~= nil
end

local function clear(buf)
	if vim.api.nvim_buf_is_valid(buf) then
		vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
	end
	last[buf] = nil
end

local function source_line(buf, row)
	local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
	if not line then
		return nil
	end
	line = vim.trim(line):gsub("%s+", " ")
	if line == "" then
		return nil
	end
	local max_width = math.max(24, math.min(160, tonumber(vim.g.nazovim_context_hint_width) or 100))
	if vim.fn.strdisplaywidth(line) > max_width then
		line = vim.fn.strcharpart(line, 0, max_width - 1) .. "…"
	end
	return line
end

local function context_text(buf, row, col)
	local ok, node = pcall(vim.treesitter.get_node, { bufnr = buf, pos = { row, col } })
	if not ok or not node then
		return nil
	end
	local best
	while node do
		local start_row, _, end_row = node:range()
		if not best and start_row < row and end_row >= row and is_scope(node:type()) then
			best = start_row
		end
		node = node:parent()
	end
	return best and source_line(buf, best) or nil
end

local function render(win)
	if not enabled or not vim.api.nvim_win_is_valid(win) then
		return
	end
	local buf = vim.api.nvim_win_get_buf(win)
	if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= "" then
		clear(buf)
		return
	end
	local cursor = vim.api.nvim_win_get_cursor(win)
	local row, col = cursor[1] - 1, cursor[2]
	local text = context_text(buf, row, col)
	local changedtick = vim.api.nvim_buf_get_changedtick(buf)
	local key = table.concat({ row, col, changedtick, text or "" }, ":")
	if last[buf] == key then
		return
	end
	vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
	last[buf] = key
	if text then
		vim.api.nvim_buf_set_extmark(buf, namespace, row, 0, {
			virt_text = { { prefix .. text, "Comment" } },
			virt_text_pos = "eol",
			priority = 80,
			hl_mode = "combine",
		})
	end
end

local function schedule(win)
	if not enabled or not vim.api.nvim_win_is_valid(win) then
		return
	end
	local buf = vim.api.nvim_win_get_buf(win)
	local timer = timers[buf]
	if not timer then
		timer = vim.uv.new_timer()
		timers[buf] = timer
	end
	timer:stop()
	timer:start(
		70,
		0,
		vim.schedule_wrap(function()
			if vim.api.nvim_win_is_valid(win) then
				render(win)
			end
		end)
	)
end

---Toggle contextual syntax hints for the current editor buffer.
function M.toggle()
	enabled = not enabled
	if not enabled then
		for buf in pairs(last) do
			clear(buf)
		end
	else
		schedule(vim.api.nvim_get_current_win())
	end
	vim.notify("Context hints " .. (enabled and "enabled" or "disabled"), vim.log.levels.INFO, { title = "NazoVim" })
end

---Attach debounced Treesitter context hints to normal editor buffers.
function M.setup()
	enabled = vim.g.nazovim_context_hint_enabled ~= false
	local group = vim.api.nvim_create_augroup("NazoVimContextHint", { clear = true })
	vim.api.nvim_create_autocmd(
		{ "CursorMoved", "CursorMovedI", "BufEnter", "TextChanged", "TextChangedI", "WinScrolled" },
		{
			group = group,
			callback = function(event)
				local win = vim.api.nvim_get_current_win()
				local buf = event.buf
				if event.event == "BufEnter" and last[buf] then
					render(win)
				else
					schedule(win)
				end
			end,
		}
	)
	vim.api.nvim_create_autocmd("BufLeave", {
		group = group,
		callback = function(event)
			clear(event.buf)
		end,
	})
	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = group,
		callback = function()
			for _, timer in pairs(timers) do
				timer:stop()
				timer:close()
			end
			timers = {}
		end,
	})
	vim.api.nvim_create_user_command("NazoContextToggle", M.toggle, { desc = "Toggle syntax context hints" })
end

return M
