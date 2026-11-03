local M = {}
local ns = vim.api.nvim_create_namespace("nazovim.jump")
local labels = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ@[;:],./_-^\\1234567890"

local function choose(buf, positions)
	if #positions == 0 then
		return nil
	end
	local marks = vim.g.jumpcursor_marks or vim.fn.split(labels, "\\zs")
	local lookup = {}
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	for i, pos in ipairs(positions) do
		local label = marks[i]
		if not label then
			break
		end
		lookup[label] = pos
		vim.api.nvim_buf_set_extmark(
			buf,
			ns,
			pos[1] - 1,
			pos[2],
			{ virt_text = { { label, "ErrorMsg" } }, virt_text_pos = "overlay" }
		)
	end
	vim.cmd("redraw")
	local ok, key = pcall(vim.fn.getcharstr)
	if vim.api.nvim_buf_is_valid(buf) then
		vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	end
	return ok and lookup[key] or nil
end

function M.jump()
	local buf, win = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
	local rows = {}
	for row = vim.fn.line("w0"), vim.fn.line("w$") do
		local text = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
		local col = text:find("%S")
		if col then
			rows[#rows + 1] = { row, col - 1 }
		end
	end
	local selected = choose(buf, rows)
	if not selected then
		return
	end
	local text = vim.api.nvim_buf_get_lines(buf, selected[1] - 1, selected[1], false)[1] or ""
	local cols = {}
	for _, char in ipairs(vim.fn.split(text, "\\zs")) do
		local offset = (cols._offset or 0)
		if not char:match("%s") then
			cols[#cols + 1] = { selected[1], offset }
		end
		cols._offset = offset + #char
	end
	selected = choose(buf, cols)
	if selected and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_win_set_cursor(win, selected)
	end
end

---Jump to a labeled Treesitter leaf node in the visible part of the buffer.
function M.treesitter_jump()
	local buf, win = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
	local ok, parser = pcall(vim.treesitter.get_parser, buf)
	if not ok or not parser then
		return M.jump()
	end
	local parsed, trees = pcall(parser.parse, parser)
	if not parsed or not trees or not trees[1] then
		return M.jump()
	end
	local first, last = vim.fn.line("w0") - 1, vim.fn.line("w$") - 1
	local positions, seen = {}, {}
	local function visit(node)
		local start_row, start_col, end_row, end_col = node:range()
		if end_row < first or start_row > last then
			return
		end
		if node:child_count() == 0 then
			if start_row >= first and start_row <= last and (start_row ~= end_row or start_col < end_col) then
				local key = start_row .. ":" .. start_col
				if not seen[key] then
					seen[key] = true
					positions[#positions + 1] = { start_row + 1, start_col }
				end
			end
			return
		end
		for index = 0, node:child_count() - 1 do
			local child = node:child(index)
			if child then
				visit(child)
			end
		end
	end
	visit(trees[1]:root())
	local selected = choose(buf, positions)
	if selected and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_win_set_cursor(win, selected)
	end
end
return M
