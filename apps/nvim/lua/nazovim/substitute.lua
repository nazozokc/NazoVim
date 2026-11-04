local M = {}

local namespace = vim.api.nvim_create_namespace("NazoVimSubstitute")
local pending
local timers = {}

local function utf8_width(line, col)
	local first = line:byte(col + 1)
	if not first then
		return 0
	elseif first < 0x80 then
		return 1
	elseif first < 0xE0 then
		return 2
	elseif first < 0xF0 then
		return 3
	end
	return 4
end

local function char_end(buf, row, col)
	local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
	return math.min(#line, col + utf8_width(line, col))
end

local function register_contents(register)
	local info = vim.fn.getreginfo(register or '"')
	local contents = type(info.regcontents) == "table" and info.regcontents or { "" }
	local valid = true
	for _, line in ipairs(contents) do
		if type(line) ~= "string" then
			valid = false
			break
		end
	end
	if not valid then
		return { "" }, "v"
	end
	return vim.deepcopy(contents), info.regtype or "v"
end

local function highlight(buf, start_row, start_col, end_row, end_col)
	if vim.g.nazovim_substitute_highlight == false or not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	if end_row == start_row and end_col <= start_col then
		return
	end
	vim.api.nvim_buf_set_extmark(buf, namespace, start_row, start_col, {
		end_row = end_row,
		end_col = end_col,
		hl_group = "IncSearch",
		priority = 180,
	})
	local timer = timers[buf]
	if not timer then
		timer = vim.uv.new_timer()
		timers[buf] = timer
	end
	timer:stop()
	timer:start(
		math.max(50, tonumber(vim.g.nazovim_substitute_highlight_ms) or 500),
		0,
		vim.schedule_wrap(function()
			if vim.api.nvim_buf_is_valid(buf) then
				vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
			end
		end)
	)
end

local function replace_block(buf, start_row, start_col, end_row, end_col, contents)
	local first_row, last_row = math.min(start_row, end_row), math.max(start_row, end_row)
	local left, right = math.min(start_col, end_col), math.max(start_col, end_col)
	for row = last_row, first_row, -1 do
		local replacement = contents[row - first_row + 1] or ""
		local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
		local from_col = math.min(left, #line)
		local finish = math.min(#line, right + utf8_width(line, right))
		vim.api.nvim_buf_set_text(buf, row - 1, from_col, row - 1, finish, { replacement })
		highlight(buf, row - 1, from_col, row - 1, from_col + #replacement)
	end
end

local function apply(buf, start_row, start_col, end_row, end_col, kind, contents)
	if not vim.api.nvim_buf_is_valid(buf) or #contents == 0 then
		return false
	end
	if start_row > end_row or (start_row == end_row and start_col > end_col) then
		start_row, end_row = end_row, start_row
		start_col, end_col = end_col, start_col
	end
	if kind == "line" then
		vim.api.nvim_buf_set_lines(buf, start_row - 1, end_row, false, contents)
		highlight(buf, start_row - 1, 0, start_row - 1 + #contents, 0)
	elseif kind == "block" then
		replace_block(buf, start_row, start_col, end_row, end_col, contents)
	else
		vim.api.nvim_buf_set_text(buf, start_row - 1, start_col, end_row - 1, end_col, contents)
		local last = contents[#contents] or ""
		local highlight_row = start_row - 1 + #contents - 1
		local highlight_col = #contents == 1 and start_col + #last or #last
		highlight(buf, start_row - 1, start_col, highlight_row, highlight_col)
	end
	return true
end

local function remember(buf, origin_row, origin_col, start_row, start_col, end_row, end_col, kind, contents)
	local row_delta_start, col_delta_start = start_row - origin_row, start_col - origin_col
	local row_delta_end, col_delta_end = end_row - origin_row, end_col - origin_col
	local snapshot = vim.deepcopy(contents)
	require("nazovim.repeat_action").set(function(target)
		local cursor = vim.api.nvim_win_get_cursor(0)
		local row, col = cursor[1], cursor[2]
		return apply(
			target,
			row + row_delta_start,
			col + col_delta_start,
			row + row_delta_end,
			col + col_delta_end,
			kind,
			vim.deepcopy(snapshot)
		)
	end, buf)
end

local function operator_range(kind)
	local first, last = vim.fn.getpos("'["), vim.fn.getpos("']")
	local start_row, start_col = first[2], math.max(0, first[3] - 1)
	local end_row, end_col = last[2], math.max(0, last[3] - 1)
	if kind == "line" then
		return start_row, 0, end_row, 0
	elseif kind == "block" then
		return start_row, start_col, end_row, end_col
	end
	return start_row, start_col, end_row, char_end(0, end_row, end_col)
end

---Operator callback that replaces the selected motion with a register snapshot.
function M.operator_callback(kind)
	local state = pending or { register = '"', origin = vim.api.nvim_win_get_cursor(0) }
	pending = nil
	local start_row, start_col, end_row, end_col = operator_range(kind)
	local contents = register_contents(state.register)
	if apply(0, start_row, start_col, end_row, end_col, kind, contents) then
		remember(0, state.origin[1], state.origin[2], start_row, start_col, end_row, end_col, kind, contents)
	end
end

---Begin an operator substitution using the selected register.
function M.operator()
	local cursor = vim.api.nvim_win_get_cursor(0)
	pending = { register = vim.v.register or '"', origin = cursor }
	vim.o.operatorfunc = "v:lua.require'nazovim.substitute'.operator_callback"
	return "g@"
end

---Replace the current line, honoring a count prefix.
function M.line()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local count = vim.v.count1
	local last = math.min(vim.api.nvim_buf_line_count(0), cursor[1] + count - 1)
	local contents = register_contents(vim.v.register)
	if apply(0, cursor[1], 0, last, 0, "line", contents) then
		remember(0, cursor[1], cursor[2], cursor[1], 0, last, 0, "line", contents)
	end
end

---Replace from the cursor through the end of the current line.
function M.eol()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local contents = register_contents(vim.v.register)
	local line = vim.api.nvim_get_current_line()
	if apply(0, cursor[1], cursor[2], cursor[1], #line, "char", contents) then
		local snapshot = vim.deepcopy(contents)
		require("nazovim.repeat_action").set(function(buf)
			local pos = vim.api.nvim_win_get_cursor(0)
			local current = vim.api.nvim_buf_get_lines(buf, pos[1] - 1, pos[1], false)[1] or ""
			return apply(buf, pos[1], pos[2], pos[1], #current, "char", vim.deepcopy(snapshot))
		end)
	end
end

---Replace the current Visual selection with the selected register.
function M.visual()
	local start_row, start_col, end_row, end_col, visual_type = require("nazovim.ui").visual_range()
	local kind = visual_type == "V" and "line" or visual_type == "\22" and "block" or "char"
	local cursor = vim.api.nvim_win_get_cursor(0)
	local contents = register_contents(vim.v.register)
	if kind == "char" then
		end_col = char_end(0, end_row, end_col)
	end
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
	if apply(0, start_row, start_col, end_row, end_col, kind, contents) then
		remember(0, cursor[1], cursor[2], start_row, start_col, end_row, end_col, kind, contents)
	end
end

---Release transient highlight timers on shutdown.
function M.setup()
	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = vim.api.nvim_create_augroup("NazoVimSubstitute", { clear = true }),
		callback = function()
			for _, timer in pairs(timers) do
				timer:stop()
				timer:close()
			end
			timers = {}
		end,
	})
	vim.keymap.set("n", "s", M.operator, { expr = true, desc = "Substitute using a register" })
	vim.keymap.set("n", "ss", M.line, { desc = "Substitute current line using a register" })
	vim.keymap.set("n", "S", M.eol, { desc = "Substitute to end of line using a register" })
	vim.keymap.set("x", "s", M.visual, { desc = "Substitute selection using a register" })
end

return M
