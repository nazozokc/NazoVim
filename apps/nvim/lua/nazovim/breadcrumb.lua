local M = {}

local cache = {}
local separator = " › "

local function display_line(buf, row)
	local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
	if not line then
		return nil
	end
	line = vim.trim(line):gsub("%s+", " ")
	if line == "" then
		return nil
	end
	local limit = math.max(30, tonumber(vim.g.nazovim_breadcrumb_width) or 90)
	if vim.fn.strdisplaywidth(line) > limit then
		line = vim.fn.strcharpart(line, 0, limit - 1) .. "…"
	end
	return line
end

local function path_label(buf)
	local name = vim.api.nvim_buf_get_name(buf)
	if name == "" then
		return "[No Name]"
	end
	return vim.fn.fnamemodify(name, ":~:.")
end

local function ancestors(buf, row, col)
	local ok, node = pcall(vim.treesitter.get_node, { bufnr = buf, pos = { row, col } })
	if not ok or not node then
		return {}
	end
	local items, seen = {}, {}
	while node do
		local start_row = node:range()
		local text = start_row <= row and display_line(buf, start_row) or nil
		if text and not seen[start_row] then
			seen[start_row] = true
			items[#items + 1] = { row = start_row, text = text, kind = node:type() }
		end
		node = node:parent()
	end
	table.sort(items, function(a, b)
		return a.row < b.row
	end)
	return items
end

local function escape_winbar(text)
	return text:gsub("%%", "%%%%")
end

local function render(win)
	if not vim.api.nvim_win_is_valid(win) then
		return
	end
	local buf = vim.api.nvim_win_get_buf(win)
	if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= "" then
		vim.api.nvim_set_option_value("winbar", "", { win = win })
		return
	end
	local cursor = vim.api.nvim_win_get_cursor(win)
	local row, col = cursor[1] - 1, cursor[2]
	local parts = { path_label(buf) }
	for _, item in ipairs(ancestors(buf, row, col)) do
		parts[#parts + 1] = item.text
	end
	local value = escape_winbar(table.concat(parts, separator))
	local key = buf .. ":" .. row .. ":" .. col .. ":" .. vim.api.nvim_buf_get_changedtick(buf) .. ":" .. value
	if cache[win] ~= key then
		vim.api.nvim_set_option_value("winbar", value, { win = win })
		cache[win] = key
	end
end

local function refresh_visible()
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		render(win)
	end
end

---Show a picker for syntax ancestors and jump to the selected declaration line.
function M.pick()
	local buf = vim.api.nvim_get_current_buf()
	local row = vim.api.nvim_win_get_cursor(0)[1] - 1
	local items = ancestors(buf, row, vim.api.nvim_win_get_cursor(0)[2])
	if #items == 0 then
		local text = display_line(buf, row)
		if text then
			items[1] = { row = row, text = text, kind = "current line" }
		end
	end
	if #items == 0 then
		vim.notify("No breadcrumb entries at this position", vim.log.levels.INFO, { title = "NazoVim" })
		return
	end
	local labels = {}
	for _, item in ipairs(items) do
		labels[#labels + 1] = string.format("%s  %s", item.kind, item.text)
	end
	vim.ui.select(labels, { prompt = "Breadcrumb:" }, function(_, index)
		local item = index and items[index]
		if item and vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_win_set_buf(0, buf)
			vim.api.nvim_win_set_cursor(0, { item.row + 1, 0 })
		end
	end)
end

---Install the buffer-local winbar breadcrumb and `<leader>;` picker.
function M.setup()
	local group = vim.api.nvim_create_augroup("NazoVimBreadcrumb", { clear = true })
	vim.api.nvim_create_autocmd(
		{ "BufEnter", "CursorMoved", "CursorMovedI", "TextChanged", "TextChangedI", "WinEnter", "WinScrolled" },
		{
			group = group,
			callback = refresh_visible,
		}
	)
	vim.api.nvim_create_autocmd("WinClosed", {
		group = group,
		callback = function(event)
			cache[tonumber(event.match)] = nil
		end,
	})
	vim.api.nvim_create_user_command("NazoBreadcrumbPick", M.pick, { desc = "Pick a syntax breadcrumb" })
	vim.keymap.set("n", "<leader>;", M.pick, { desc = "Pick breadcrumb symbol" })
	refresh_visible()
end

return M
