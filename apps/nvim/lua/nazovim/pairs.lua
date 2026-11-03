local M = {}

local pair_map = {
	["("] = ")",
	["["] = "]",
	["{"] = "}",
	['"'] = '"',
	["'"] = "'",
	["`"] = "`",
}

local closing = {}
for open, close in pairs(pair_map) do
	closing[close] = open
end

local function termcodes(keys)
	return vim.api.nvim_replace_termcodes(keys, true, false, true)
end

---Return true when the position is inside a comment or string according to Treesitter.
---Buffers without a parser simply fall back to plain pairing.
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

---Characters on both sides of the insert-mode cursor.
local function around()
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	local line = vim.api.nvim_get_current_line()
	return row, col, line:sub(col, col), line:sub(col + 1, col + 1)
end

---Open a bracket pair when the next character is not part of an identifier.
---Quotes pair unless the cursor follows a word (e.g. the apostrophe in "don't").
function M.open(char)
	local row, col, before, after = around()
	local close = pair_map[char]
	if not close then
		return char
	end
	local buf = vim.api.nvim_get_current_buf()
	if in_comment_or_string(buf, row - 1, col) then
		return char
	end
	if char == close then
		if after == char then
			return termcodes("<C-g>U<Right>")
		end
		if before:match("[%w_]") then
			return char
		end
	elseif after:match("[%w_]") then
		return char
	end
	return char .. close .. termcodes("<C-g>U<Left>")
end

---Move over an existing closing character instead of inserting a duplicate.
function M.close(char)
	local _, _, before, after = around()
	if after ~= char then
		return char
	end
	if before:match("[%w_]") and closing[char] == char then
		return char
	end
	return termcodes("<C-g>U<Right>")
end

---Delete both halves of an empty pair with a single backspace.
function M.backspace()
	local _, _, before, after = around()
	if after ~= "" and pair_map[before] == after then
		return termcodes("<C-g>U<BS><BS>")
	end
	return termcodes("<C-g>U<BS>")
end

---Expand an empty pair into an indented block when pressing Enter.
function M.enter()
	local row, col, before, after = around()
	if after == "" or pair_map[before] ~= after then
		vim.api.nvim_feedkeys(termcodes("<CR>"), "n", false)
		return
	end
	local line = vim.api.nvim_get_current_line()
	local base = line:match("^%s*") or ""
	local shift = vim.bo.expandtab and string.rep(" ", vim.bo.shiftwidth) or "\t"
	local inner = base .. shift
	vim.api.nvim_buf_set_text(0, row - 1, col, row - 1, col, { "\n" .. inner .. "\n" .. base })
	vim.api.nvim_win_set_cursor(0, { row + 1, #inner })
end

---Attach buffer-local insert-mode mappings once.
function M.attach(buf)
	if vim.b[buf].nazo_pairs then
		return
	end
	vim.b[buf].nazo_pairs = true
	for open in pairs(pair_map) do
		vim.keymap.set("i", open, function()
			return M.open(open)
		end, { buffer = buf, expr = true, desc = "Auto pair " .. open })
	end
	for close in pairs(closing) do
		vim.keymap.set("i", close, function()
			return M.close(close)
		end, { buffer = buf, expr = true, desc = "Skip closing " .. close })
	end
	vim.keymap.set("i", "<BS>", M.backspace, { buffer = buf, expr = true, desc = "Delete pair" })
	vim.keymap.set("i", "<CR>", M.enter, { buffer = buf, desc = "Expand pair" })
end

---Install the InsertEnter hook used to lazily attach buffers.
function M.setup()
	local group = vim.api.nvim_create_augroup("NazoPairs", { clear = true })
	vim.api.nvim_create_autocmd({ "BufEnter", "FileType" }, {
		group = group,
		callback = function(args)
			M.attach(args.buf)
		end,
	})
end

return M
