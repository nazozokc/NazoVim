local M = {}

---Expand the bundled template placeholders; unknown placeholders remain literal.
function M.expand(lines, filename)
	local stem = vim.fn.fnamemodify(filename, ":t:r")
	local values = {
		file_name = stem,
		upper_file = stem:upper(),
		camel_case_file = (stem:gsub("^%l", string.upper):gsub("[_%-](%w)", string.upper)),
		date = os.date("%Y-%m-%d"),
		author = vim.g.nazovim_template_author or "nazozokc",
		email = vim.g.nazovim_template_email or "",
		cursor = "",
	}
	local output, cursor = {}, nil
	for row, line in ipairs(lines) do
		local expanded = line:gsub("{{_([%w_]+)_}}", function(key)
			return key == "cursor" and "{{_cursor_}}" or values[key]
		end)
		local col = expanded:find("{{_cursor_}}", 1, true)
		if col and not cursor then
			cursor = { row, col - 1 }
		end
		output[row] = expanded:gsub("{{_cursor_}}", "")
	end
	return output, cursor
end

return M
