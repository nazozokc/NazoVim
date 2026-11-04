local M = {}

local pairs = {
	["("] = ")",
	["["] = "]",
	["{"] = "}",
	["<"] = ">",
	['"'] = '"',
	["'"] = "'",
	["`"] = "`",
}

local function termcodes(keys)
	return vim.api.nvim_replace_termcodes(keys, true, false, true)
end

local function in_comment_or_string(buf, row, col)
	local ok, node = pcall(vim.treesitter.get_node, { bufnr = buf, pos = { row, col } })
	if not ok or not node then
		return false
	end
	while node do
		local kind = node:type()
		if kind:find("comment") or kind:find("string") then
			return true
		end
		node = node:parent()
	end
	return false
end

local function escaped(line, col)
	local count, i = 0, col
	while i > 0 and line:sub(i, i) == "\\" do
		count = count + 1
		i = i - 1
	end
	return count % 2 == 1
end

---Find the nearest pair around a position. Returns 0-based columns.
---@return table|nil { srow, scol, erow, ecol }
function M.find(buf, row, col, open, close)
	local total = vim.api.nvim_buf_line_count(buf)
	if row < 1 or row > total then
		return nil
	end
	if open == close then
		local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
		local start_col
		for i = math.min(col + 1, #line), 1, -1 do
			if
				line:sub(i, i) == open
				and not escaped(line, i - 1)
				and not in_comment_or_string(buf, row - 1, i - 1)
			then
				start_col = i - 1
				break
			end
		end
		local end_col
		for i = math.max(col + 2, 1), #line do
			if
				line:sub(i, i) == close
				and not escaped(line, i - 1)
				and not in_comment_or_string(buf, row - 1, i - 1)
			then
				end_col = i - 1
				break
			end
		end
		if start_col and end_col then
			return { srow = row, scol = start_col, erow = row, ecol = end_col }
		end
		return nil
	end

	local depth = 0
	for r = row, 1, -1 do
		local line = vim.api.nvim_buf_get_lines(buf, r - 1, r, false)[1] or ""
		local first = r == row and math.min(col + 1, #line) or #line
		for c = first, 1, -1 do
			local ch = line:sub(c, c)
			if not in_comment_or_string(buf, r - 1, c - 1) then
				if ch == close then
					depth = depth + 1
				elseif ch == open then
					if depth == 0 then
						local srow, scol = r, c - 1
						-- Scan forward from the opening character for its match.
						local inner = 0
						for fr = srow, total do
							local fline = vim.api.nvim_buf_get_lines(buf, fr - 1, fr, false)[1] or ""
							local start = fr == srow and scol + 1 or 0
							for fc = start, #fline - 1 do
								local fch = fline:sub(fc + 1, fc + 1)
								if not in_comment_or_string(buf, fr - 1, fc) then
									if fch == open then
										inner = inner + 1
									elseif fch == close then
										if inner == 0 then
											return { srow = srow, scol = scol, erow = fr, ecol = fc }
										end
										inner = inner - 1
									end
								end
							end
						end
						return nil
					else
						depth = depth - 1
					end
				end
			end
		end
	end
	return nil
end

local function remove_char(buf, row, col)
	vim.api.nvim_buf_set_text(buf, row - 1, col, row - 1, col + 1, {})
end

---Delete the pair around the cursor. Returns true when a pair was removed.
function M.delete(buf, row, col, open, close)
	local found = M.find(buf, row, col, open, close)
	if not found then
		return false
	end
	remove_char(buf, found.erow, found.ecol)
	remove_char(buf, found.srow, found.scol)
	return true
end

---Replace the pair around the cursor. Returns true when a pair was replaced.
function M.replace(buf, row, col, old_open, old_close, new_open, new_close)
	local found = M.find(buf, row, col, old_open, old_close)
	if not found then
		return false
	end
	vim.api.nvim_buf_set_text(buf, found.erow - 1, found.ecol, found.erow - 1, found.ecol + 1, { new_close })
	vim.api.nvim_buf_set_text(buf, found.srow - 1, found.scol, found.srow - 1, found.scol + 1, { new_open })
	return true
end

---Add a surrounding pair. Positions are 1-based rows and 0-based byte columns.
---`ecol` is exclusive for characterwise ranges.
function M.add(buf, srow, scol, erow, ecol, open, close, linewise)
	if linewise then
		local indent = (vim.api.nvim_buf_get_lines(buf, srow - 1, srow, false)[1] or ""):match("^%s*") or ""
		vim.api.nvim_buf_set_lines(buf, erow, erow, false, { indent .. close })
		vim.api.nvim_buf_set_lines(buf, srow - 1, srow - 1, false, { indent .. open })
		return
	end
	if srow > erow or (srow == erow and scol > ecol) then
		srow, erow = erow, srow
		scol, ecol = ecol, scol
	end
	vim.api.nvim_buf_set_text(buf, erow - 1, ecol, erow - 1, ecol, { close })
	vim.api.nvim_buf_set_text(buf, srow - 1, scol, srow - 1, scol, { open })
end

local function prompt(label)
	vim.api.nvim_echo({ { label, "Question" } }, false, {})
	local ok, char = pcall(vim.fn.getcharstr)
	vim.cmd.redraw()
	if not ok or char == "" or char == "\27" then
		return nil
	end
	return char
end

local function remember_add(anchor, srow, scol, erow, ecol, open, close, linewise)
	local start_row, start_col = srow - anchor[1], scol - anchor[2]
	local end_row, end_col = erow - anchor[1], ecol - anchor[2]
	require("nazovim.repeat_action").set(function(buf)
		local cursor = vim.api.nvim_win_get_cursor(0)
		local row, col = cursor[1], cursor[2]
		M.add(buf, row + start_row, col + start_col, row + end_row, col + end_col, open, close, linewise)
		return true
	end)
end

---Operator function for `sa`.
function M.add_operator(type)
	local first, last = vim.fn.getpos("'["), vim.fn.getpos("']")
	local anchor = M.pending_anchor or { first[2], first[3] - 1 }
	M.pending_anchor = nil
	local char = prompt("Surround with: ")
	if not char then
		return
	end
	local open, close = char, pairs[char] or char
	local linewise = type == "line"
	local srow, scol, erow, ecol = first[2], first[3] - 1, last[2], last[3]
	M.add(0, srow, scol, erow, ecol, open, close, linewise)
	remember_add(anchor, srow, scol, erow, ecol, open, close, linewise)
end

local function visual_add()
	local srow, scol, erow, ecol, kind = require("nazovim.ui").visual_range()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local char = prompt("Surround with: ")
	if not char then
		return
	end
	local open, close = char, pairs[char] or char
	M.add(0, srow, scol, erow, ecol + 1, open, close, kind == "V")
	remember_add({ cursor[1], cursor[2] }, srow, scol, erow, ecol + 1, open, close, kind == "V")
	vim.api.nvim_feedkeys(termcodes("<Esc>"), "nx", false)
end

local function delete_prompt()
	local char = prompt("Delete surrounding: ")
	if not char then
		return
	end
	local cursor = vim.api.nvim_win_get_cursor(0)
	if M.delete(0, cursor[1], cursor[2], char, pairs[char] or char) then
		require("nazovim.repeat_action").set(function(buf)
			local pos = vim.api.nvim_win_get_cursor(0)
			return M.delete(buf, pos[1], pos[2], char, pairs[char] or char)
		end)
	end
end

local function replace_prompt()
	local old = prompt("Replace surrounding: ")
	if not old then
		return
	end
	local new = prompt("With: ")
	if not new then
		return
	end
	local cursor = vim.api.nvim_win_get_cursor(0)
	if M.replace(0, cursor[1], cursor[2], old, pairs[old] or old, new, pairs[new] or new) then
		require("nazovim.repeat_action").set(function(buf)
			local pos = vim.api.nvim_win_get_cursor(0)
			return M.replace(buf, pos[1], pos[2], old, pairs[old] or old, new, pairs[new] or new)
		end)
	end
end

function M.setup()
	vim.keymap.set("n", "sa", function()
		local cursor = vim.api.nvim_win_get_cursor(0)
		M.pending_anchor = { cursor[1], cursor[2] }
		vim.o.operatorfunc = "v:lua.require'nazovim.surround'.add_operator"
		return "g@"
	end, { expr = true, desc = "Add surrounding" })
	vim.keymap.set("x", "sa", visual_add, { desc = "Add surrounding" })
	vim.keymap.set("n", "sd", delete_prompt, { desc = "Delete surrounding" })
	vim.keymap.set("n", "sr", replace_prompt, { desc = "Replace surrounding" })
end

return M
