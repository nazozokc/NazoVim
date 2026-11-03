local M = {}

local function headings(buf)
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local result, seen = {}, {}
	for row, line in ipairs(lines) do
		local hashes, title = line:match("^%s*(#+)%s+(.-)%s*$")
		if hashes and #hashes <= 6 then
			title = title:gsub("%s+#+%s*$", "")
			if title ~= "" then
				result[#result + 1] = { row = row, level = #hashes, title = title }
				seen[row] = true
			end
		elseif row > 1 and not line:match("^%s*$") then
			local level = line:match("^%s*(=+)%s*$") and 1 or line:match("^%s*(-+)%s*$") and 2
			local previous = lines[row - 1] or ""
			if level and previous:match("%S") and not seen[row - 1] then
				result[#result + 1] = { row = row - 1, level = level, title = vim.trim(previous) }
				seen[row - 1] = true
			end
		end
	end
	return result
end

local function display_title(entry)
	return string.rep("  ", entry.level - 1) .. entry.title
end

local function preview(win, buf, row)
	if not vim.api.nvim_win_is_valid(win) or not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	local target = math.max(1, math.min(row, vim.api.nvim_buf_line_count(buf)))
	vim.api.nvim_win_set_cursor(win, { target, 0 })
	vim.api.nvim_win_call(win, function()
		vim.cmd("normal! zz")
	end)
end

---Open a navigable outline of Markdown headings in the current buffer.
function M.open()
	local origin_win, buf = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
	if vim.bo[buf].filetype ~= "markdown" then
		vim.notify("Markdown outline is available in Markdown buffers", vim.log.levels.INFO, { title = "NazoVim" })
		return
	end
	local entries = headings(buf)
	if #entries == 0 then
		vim.notify("No Markdown headings found", vim.log.levels.INFO, { title = "NazoVim" })
		return
	end
	local previous_row = vim.api.nvim_win_get_cursor(origin_win)[1]
	local picker = vim.api.nvim_create_buf(false, true)
	vim.bo[picker].buftype = "nofile"
	vim.bo[picker].bufhidden = "wipe"
	vim.bo[picker].swapfile = false
	local items = {}
	for _, entry in ipairs(entries) do
		items[#items + 1] = display_title(entry)
	end
	vim.api.nvim_buf_set_lines(picker, 0, -1, false, items)
	vim.bo[picker].modifiable = false
	vim.bo[picker].filetype = "nazovim-outline"
	local width = math.min(math.max(32, math.floor(vim.o.columns * 0.6)), math.max(1, vim.o.columns - 4))
	local height = math.min(#items, math.max(1, vim.o.lines - vim.o.cmdheight - 6))
	local win = vim.api.nvim_open_win(picker, true, {
		relative = "editor",
		row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
		col = math.max(0, math.floor((vim.o.columns - width) / 2)),
		width = width,
		height = height,
		style = "minimal",
		border = "rounded",
		title = " Markdown Outline ",
		title_pos = "center",
	})
	vim.wo[win].cursorline = true
	vim.wo[win].wrap = false
	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].signcolumn = "no"
	local closed, accepted, selected_row = false, false, 1
	local function close()
		if closed then
			return
		end
		closed = true
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
		if vim.api.nvim_win_is_valid(origin_win) then
			if accepted then
				local line = entries[selected_row]
				if line then
					preview(origin_win, buf, line.row)
				end
			else
				preview(origin_win, buf, previous_row)
			end
			vim.api.nvim_set_current_win(origin_win)
		end
	end
	local function move(delta)
		selected_row = math.max(1, math.min(#entries, selected_row + delta))
		vim.api.nvim_win_set_cursor(win, { selected_row, 0 })
		preview(origin_win, buf, entries[selected_row].row)
	end
	local map_opts = { buffer = picker, silent = true, nowait = true }
	for _, key in ipairs({ "j", "<Down>" }) do
		vim.keymap.set("n", key, function()
			move(1)
		end, map_opts)
	end
	for _, key in ipairs({ "k", "<Up>" }) do
		vim.keymap.set("n", key, function()
			move(-1)
		end, map_opts)
	end
	vim.keymap.set("n", "<CR>", function()
		selected_row = vim.api.nvim_win_get_cursor(win)[1]
		accepted = true
		close()
	end, map_opts)
	vim.keymap.set("n", "q", close, map_opts)
	vim.keymap.set("n", "<Esc>", close, map_opts)
	vim.api.nvim_create_autocmd("WinClosed", {
		pattern = tostring(win),
		once = true,
		callback = function()
			close()
		end,
	})
	preview(origin_win, buf, entries[1].row)
end

---Register commands that open the Markdown outline picker.
function M.setup()
	vim.api.nvim_create_user_command("MdOutline", M.open, { desc = "Open Markdown outline" })
	vim.api.nvim_create_user_command("NazoMarkdownOutline", M.open, { desc = "Open Markdown outline" })
end

return M
