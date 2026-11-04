local M = {}

local constants = {
	let = { "let", "const", "var" },
	const = { "let", "const", "var" },
	var = { "let", "const", "var" },
	small = { "small", "medium", "large" },
	medium = { "small", "medium", "large" },
	large = { "small", "medium", "large" },
}

local function all_tokens(line)
	local found = {}
	local function add(kind, pattern)
		local init = 1
		while true do
			local first, last = line:find(pattern, init)
			if not first then
				break
			end
			local before = first > 1 and line:sub(first - 1, first - 1) or ""
			if before:match("[%w_%.]") then
				-- A signed number after an identifier ("foo-1") must still count,
				-- so retry from the next byte instead of skipping the match.
				init = first + 1
			else
				local token = { start = first - 1, finish = last, text = line:sub(first, last), kind = kind }
				local overlaps = false
				for _, other in ipairs(found) do
					if token.start < other.finish and other.start < token.finish then
						overlaps = true
						break
					end
				end
				if not overlaps then
					found[#found + 1] = token
				end
				init = last + 1
			end
		end
	end
	add("bool", "%f[%w_]true%f[^%w_]")
	add("bool", "%f[%w_]false%f[^%w_]")
	for word in pairs(constants) do
		add("const", "%f[%w_]" .. word .. "%f[^%w_]")
	end
	add("hex", "0[xX]%x+")
	add("binary", "0[bB][01]+")
	add("float", "[-+]?%d[%d_]*%.%d+")
	add("int", "[-+]?%d[%d_]*")
	table.sort(found, function(a, b)
		return a.start < b.start
	end)
	return found
end

---All tokens on a line, ordered by start column.
function M.tokens(line)
	return all_tokens(line)
end

---Find the token under a byte column. Returns nil when the cursor is not on a token.
function M.find(line, col)
	for _, token in ipairs(all_tokens(line)) do
		if col >= token.start and col < token.finish then
			return token
		end
	end
	return nil
end

local function pad(number, width)
	local text = tostring(math.abs(number))
	while #text < width do
		text = "0" .. text
	end
	return (number < 0 and "-" or "") .. text
end

---Return the next value for a token, preserving its notation.
function M.next(token, step)
	local text = token.text
	if token.kind == "bool" then
		return text == "true" and "false" or "true"
	elseif token.kind == "const" then
		local list = constants[text]
		if not list then
			return nil
		end
		local index = 1
		for i, value in ipairs(list) do
			if value == text then
				index = i
			end
		end
		return list[(index - 1 + step) % #list + 1]
	elseif token.kind == "hex" then
		local prefix = text:match("^0[xX]")
		local digits = text:sub(3):gsub("_", "")
		local value = tonumber(digits, 16)
		if not value then
			return nil
		end
		value = value + step
		if value < 0 then
			return nil
		end
		local formatted = string.format("%0" .. #digits .. "x", value)
		if digits:match("%u") and not digits:match("%l") then
			formatted = formatted:upper()
		end
		return prefix .. formatted
	elseif token.kind == "binary" then
		local prefix = text:match("^0[bB]")
		local digits = text:sub(3)
		local value = tonumber(digits, 2)
		if not value then
			return nil
		end
		value = value + step
		if value < 0 then
			return nil
		end
		local formatted = ""
		repeat
			formatted = tostring(value % 2) .. formatted
			value = math.floor(value / 2)
		until value == 0
		while #formatted < #digits do
			formatted = "0" .. formatted
		end
		return prefix .. formatted
	elseif token.kind == "float" then
		local decimals = #(text:match("%.(%d+)$") or "")
		local value = tonumber((text:gsub("_", "")))
		if not value then
			return nil
		end
		return string.format("%." .. decimals .. "f", value + step * 10 ^ -decimals)
	elseif token.kind == "int" then
		local value = tonumber((text:gsub("_", "")))
		if not value then
			return nil
		end
		local width = #(text:gsub("^[-+]", ""))
		return pad(value + step, width)
	end
	return nil
end

local function replace_token(buf, row, token, step)
	local value = M.next(token, step)
	if not value then
		return false
	end
	vim.api.nvim_buf_set_text(buf, row - 1, token.start, row - 1, token.finish, { value })
	return true
end

---Increment or decrement tokens on a line. `from` and `to` are inclusive
---0-based byte columns; omit them to cover the whole line.
function M.increment_line(line, step, from, to)
	from = from or 0
	to = to or math.max(0, #line - 1)
	local result, position = {}, 1
	for _, token in ipairs(all_tokens(line)) do
		if token.start <= to and token.finish > from then
			local value = M.next(token, step) or token.text
			result[#result + 1] = line:sub(position, token.start)
			result[#result + 1] = value
			position = token.finish + 1
		end
	end
	result[#result + 1] = line:sub(position)
	return table.concat(result)
end

local function visual(step)
	local srow, scol, erow, ecol, kind = require("nazovim.ui").visual_range()
	for row = srow, erow do
		local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ""
		local from, to
		if kind == "V" then
			from, to = 0, math.max(0, #line - 1)
		elseif kind == "\22" then
			from, to = scol, ecol
		else
			from = row == srow and scol or 0
			to = row == erow and ecol or math.max(0, #line - 1)
		end
		if from <= to then
			vim.api.nvim_buf_set_lines(0, row - 1, row, false, { M.increment_line(line, step, from, to) })
		end
	end
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
end

---Increment/decrement the token under the cursor, falling back to native <C-a>/<C-x>.
function M.increment(step)
	local current = vim.fn.mode(1)
	if current == "v" or current == "V" or current == "\22" then
		visual(step)
		return
	end
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	local line = vim.api.nvim_get_current_line()
	local token = M.find(line, col)
	if not token or not replace_token(0, row, token, step) then
		vim.cmd.normal({ args = { string.char(step > 0 and 1 or 24) }, bang = true })
	end
end

function M.setup()
	vim.keymap.set({ "n", "x" }, "<C-a>", function()
		M.increment(1)
	end, { desc = "Increment" })
	vim.keymap.set({ "n", "x" }, "<C-x>", function()
		M.increment(-1)
	end, { desc = "Decrement" })
end

return M
