local kinds = require("nazovim.todo.kinds")

local M = {}
local ns = vim.api.nvim_create_namespace("NazoTodo")

---Extract keyword ranges from a line (byte columns, with a required colon).
function M.matches(line)
	local result = {}
	for first, word, after in line:gmatch("()%f[%w_]([A-Z]+)%f[^%w_]:()") do
		if kinds[word] then
			result[#result + 1] = { first = first - 1, last = after - 1, word = word, hl = kinds[word] }
		end
	end
	return result
end

local function comment(buf, row, col, line)
	local ok, node = pcall(vim.treesitter.get_node, { bufnr = buf, pos = { row, col } })
	if ok and node then
		while node do
			if node:type():find("comment") then
				return true
			end
			node = node:parent()
		end
		return false
	end
	local syntax = vim.api.nvim_buf_call(buf, function()
		return vim.fn.synIDattr(vim.fn.synID(row + 1, col + 1, 1), "name")
	end)
	if syntax:lower():find("comment") then
		return true
	end
	if syntax:lower():find("string") then
		return false
	end
	local prefix = vim.bo[buf].commentstring:match("^(.-)%%s")
	prefix = prefix and vim.trim(prefix)
	if not prefix or prefix == "" then
		return false
	end
	-- Fallback for buffers without parsers/syntax: skip quoted strings before the comment.
	local quote, i = nil, 1
	while i <= col + 1 do
		local char = line:sub(i, i)
		if quote then
			if char == "\\" then
				i = i + 1
			elseif char == quote then
				quote = nil
			end
		elseif line:sub(i, i + #prefix - 1) == prefix then
			return true
		elseif char == '"' or char == "'" or char == "`" then
			quote = char
		end
		i = i + 1
	end
	return false
end

local function render(buf, rows)
	for row in pairs(rows) do
		local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
		if #line <= 4096 then
			for _, item in ipairs(M.matches(line)) do
				if comment(buf, row - 1, item.first, line) then
					vim.api.nvim_buf_set_extmark(
						buf,
						ns,
						row - 1,
						item.first,
						{ end_col = item.last, hl_group = item.hl, priority = 140 }
					)
				end
			end
		end
	end
end

---Highlight TODO keywords in comments without a plugin dependency.
function M.setup()
	require("nazovim.ui").decorate("NazoTodo", ns, render)
end

return M
