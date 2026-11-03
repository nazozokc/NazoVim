local M = {}
local jump = { char = nil, direction = 1, till = false }

local function split_camel(text, base)
	local chars = vim.fn.split(text, "\\zs")
	local result, buffer = {}, {}
	local start, pos = base, base
	for i, char in ipairs(chars) do
		local previous, following = chars[i - 1], chars[i + 1]
		local boundary = i > 1
			and char:match("%u")
			and (
				(previous:match("%l") or previous:match("%d"))
				or (previous:match("%u") and following and following:match("%l"))
			)
		if boundary then
			result[#result + 1] = { start = start, finish = pos, text = table.concat(buffer) }
			start = pos
			buffer = {}
		end
		buffer[#buffer + 1] = char
		pos = pos + #char
	end
	if #buffer > 0 then
		result[#result + 1] = { start = start, finish = pos, text = table.concat(buffer) }
	end
	return result
end

---Split a line into camelCase / snake_case aware word tokens.
function M.tokens(line)
	local chars = vim.fn.split(line, "\\zs")
	local result = {}
	local i, pos = 1, 0
	while i <= #chars do
		local char = chars[i]
		if char:match("%s") then
			pos = pos + #char
			i = i + 1
		elseif char:match("[%w_]") then
			local segment = {}
			local segment_start = pos
			while i <= #chars and chars[i]:match("[%w_]") do
				if chars[i] == "_" then
					if #segment > 0 then
						vim.list_extend(result, split_camel(table.concat(segment), segment_start))
						segment = {}
					end
					pos = pos + #chars[i]
					i = i + 1
					segment_start = pos
				else
					if #segment == 0 then
						segment_start = pos
					end
					segment[#segment + 1] = chars[i]
					pos = pos + #chars[i]
					i = i + 1
				end
			end
			if #segment > 0 then
				vim.list_extend(result, split_camel(table.concat(segment), segment_start))
			end
		else
			result[#result + 1] = { start = pos, finish = pos + #char, text = char }
			pos = pos + #char
			i = i + 1
		end
	end
	return result
end

local function tokens_for_row(buf, row)
	local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
	return M.tokens(line)
end

local function last_char_start(token)
	local chars = vim.fn.split(token.text, "\\zs")
	return token.finish - #chars[#chars]
end

---Move by a spider-style motion. `kind` is one of w/e/b/ge.
function M.move(kind, count)
	count = count or 1
	local buf = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row, col = cursor[1], cursor[2]
	local total = vim.api.nvim_buf_line_count(buf)
	for _ = 1, count do
		local moved = false
		if kind == "w" then
			for r = row, total do
				for _, token in ipairs(tokens_for_row(buf, r)) do
					if r > row or token.start > col then
						row, col, moved = r, token.start, true
						break
					end
				end
				if moved then
					break
				end
			end
		elseif kind == "e" then
			for r = row, total do
				for _, token in ipairs(tokens_for_row(buf, r)) do
					local last = last_char_start(token)
					if r > row or last > col then
						row, col, moved = r, last, true
						break
					end
				end
				if moved then
					break
				end
			end
		elseif kind == "b" then
			for r = row, 1, -1 do
				local tokens = tokens_for_row(buf, r)
				for i = #tokens, 1, -1 do
					if r < row or tokens[i].start < col then
						row, col, moved = r, tokens[i].start, true
						break
					end
				end
				if moved then
					break
				end
			end
		elseif kind == "ge" then
			for r = row, 1, -1 do
				local tokens = tokens_for_row(buf, r)
				for i = #tokens, 1, -1 do
					if r < row or tokens[i].finish <= col then
						row, col, moved = r, last_char_start(tokens[i]), true
						break
					end
				end
				if moved then
					break
				end
			end
		end
		if not moved then
			break
		end
	end
	vim.api.nvim_win_set_cursor(0, { row, col })
end

local function find_match(char, direction, till)
	local pos = vim.api.nvim_win_get_cursor(0)
	local row, col = pos[1], pos[2]
	local line_count = vim.api.nvim_buf_line_count(0)
	while row >= 1 and row <= line_count do
		local text = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ""
		local index
		if direction > 0 then
			local start = col + 2
			while start <= #text do
				local found = text:find(char, start, true)
				if not found then
					break
				end
				local byte = text:byte(found)
				if byte < 0x80 or byte >= 0xC0 then
					index = found
					break
				end
				start = found + 1
			end
		else
			local start = 1
			while true do
				local found = text:find(char, start, true)
				if not found or found - 1 >= col then
					break
				end
				local byte = text:byte(found)
				if byte < 0x80 or byte >= 0xC0 then
					index = found
				end
				start = found + 1
			end
		end
		if index then
			return { row, index - 1 + (till and -direction or 0) }
		end
		row = row + direction
		col = direction > 0 and -1 or math.huge
	end
end

local function repeat_jump(reverse)
	if not jump.char then
		return
	end
	local direction = reverse and -jump.direction or jump.direction
	for _ = 1, vim.v.count1 do
		local found = find_match(jump.char, direction, jump.till)
		if not found then
			break
		end
		vim.api.nvim_win_set_cursor(0, found)
	end
end

function M.setup()
	local directions = { f = { 1, false }, F = { -1, false }, t = { 1, true }, T = { -1, true } }
	for key, motion in pairs(directions) do
		vim.keymap.set({ "n", "x", "o" }, key, function()
			local ok, char = pcall(vim.fn.getcharstr)
			if not ok or char == "" then
				return
			end
			-- getcharstr() can return a special-key encoding; find() expects literal text.
			if vim.fn.strchars(char) ~= 1 then
				return
			end
			jump = { char = char, direction = motion[1], till = motion[2] }
			for _ = 1, vim.v.count1 do
				local found = find_match(char, motion[1], motion[2])
				if not found then
					break
				end
				vim.api.nvim_win_set_cursor(0, found)
			end
		end, { desc = "Jump to character" })
	end
	vim.keymap.set({ "n", "x", "o" }, ";", function()
		repeat_jump(false)
	end, { desc = "Repeat character jump" })
	vim.keymap.set({ "n", "x", "o" }, ",", function()
		repeat_jump(true)
	end, { desc = "Reverse character jump" })
	local function map(key, kind, description)
		vim.keymap.set({ "n", "x", "o" }, key, function()
			M.move(kind, vim.v.count1)
		end, { desc = description })
	end
	map("w", "w", "Next subword")
	map("e", "e", "End of subword")
	map("b", "b", "Previous subword")
	map("ge", "ge", "End of previous subword")
end

return M
