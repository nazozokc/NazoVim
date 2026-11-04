local M = {}
local history = {}
local loaded = false
local path = vim.fn.stdpath("state") .. "/nazovim/clipboard-history.json"

local function limit()
	return math.max(1, math.min(1000, tonumber(vim.g.nazovim_clipboard_history_limit) or 100))
end

local function persistent()
	return vim.g.nazovim_clipboard_history_persist ~= false
end

local function notify(message, level)
	vim.notify(message, level or vim.log.levels.INFO, { title = "NazoVim Clipboard" })
end

local function load_history()
	if loaded then
		return
	end
	loaded = true
	if not persistent() or vim.fn.filereadable(path) ~= 1 then
		return
	end
	local lines = vim.fn.readfile(path)
	local ok, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))
	if not ok or type(decoded) ~= "table" then
		notify("Could not read clipboard history; starting with an empty list", vim.log.levels.WARN)
		return
	end
	for _, item in ipairs(decoded) do
		if type(item) == "table" and type(item.contents) == "table" and type(item.regtype) == "string" then
			local valid = true
			for _, line in ipairs(item.contents) do
				if type(line) ~= "string" then
					valid = false
					break
				end
			end
			if valid then
				history[#history + 1] = item
				if #history >= limit() then
					break
				end
			end
		end
	end
end

local function save_history()
	if not persistent() then
		return true
	end
	local directory = vim.fn.fnamemodify(path, ":h")
	vim.fn.mkdir(directory, "p")
	local temporary = path .. ".tmp"
	local ok, encoded = pcall(vim.json.encode, history)
	if not ok then
		notify("Could not encode clipboard history: " .. tostring(encoded), vim.log.levels.ERROR)
		return false
	end
	local result = vim.fn.writefile({ encoded }, temporary)
	if result ~= 0 then
		notify("Could not write clipboard history", vim.log.levels.ERROR)
		return false
	end
	local renamed, err = vim.uv.fs_rename(temporary, path)
	if not renamed then
		vim.fn.delete(temporary)
		notify("Could not replace clipboard history: " .. tostring(err), vim.log.levels.ERROR)
		return false
	end
	return true
end

local function register_yank(event)
	if vim.g.nazovim_clipboard_history_disabled then
		return
	end
	local register = event.regname or ""
	if register == "_" or type(event.regcontents) ~= "table" or #event.regcontents == 0 then
		return
	end
	local operator = event.operator
	if operator ~= "y" and operator ~= "d" and operator ~= "c" and operator ~= "x" and operator ~= "s" then
		return
	end
	local item = {
		contents = vim.deepcopy(event.regcontents),
		regtype = event.regtype or "v",
		register = register,
		timestamp = os.time(),
	}
	local previous = history[1]
	if previous and previous.regtype == item.regtype and vim.deep_equal(previous.contents, item.contents) then
		previous.timestamp = item.timestamp
	else
		table.insert(history, 1, item)
	end
	while #history > limit() do
		table.remove(history)
	end
	save_history()
end

local function preview_lines(item)
	local lines =
		{ string.format("Register: %s   Type: %s", item.register == "" and '"' or item.register, item.regtype) }
	vim.list_extend(lines, item.contents)
	return lines
end

local function summary(item, width)
	local text = table.concat(item.contents, "  "):gsub("\t", " ")
	local max = math.max(8, width - 16)
	if vim.fn.strdisplaywidth(text) > max then
		text = vim.fn.strcharpart(text, 0, max - 1) .. "…"
	end
	local kind = item.regtype:sub(1, 1) == "V" and "LINE" or item.regtype:sub(1, 1) == "\22" and "BLOCK" or "CHAR"
	local register = item.register == "" and '"' or item.register
	return string.format("%-5s %-5s %s", kind, register, text)
end

local function filtered_items(query)
	local matches = {}
	query = query:lower()
	for _, item in ipairs(history) do
		local text = table.concat(item.contents, "\n")
		if query == "" or text:lower():find(query, 1, true) then
			matches[#matches + 1] = item
		end
	end
	return matches
end

local function open_editor(item, on_save)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "acwrite"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, item.contents)
	vim.api.nvim_buf_set_name(buf, "NazoClipboardEdit")
	local width = math.min(math.max(40, math.floor(vim.o.columns * 0.7)), math.max(1, vim.o.columns - 4))
	local height = math.min(math.max(3, #item.contents), math.max(1, vim.o.lines - vim.o.cmdheight - 6))
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
		col = math.max(0, math.floor((vim.o.columns - width) / 2)),
		width = width,
		height = height,
		style = "minimal",
		border = "rounded",
		title = " Edit clipboard item ",
		title_pos = "center",
	})
	local saved = false
	local function save()
		item.contents = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		saved = true
		on_save()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end
	vim.api.nvim_create_autocmd("BufWriteCmd", {
		buffer = buf,
		callback = save,
	})
	vim.keymap.set("n", "<C-s>", save, { buffer = buf, desc = "Save clipboard item" })
	vim.keymap.set("n", "q", function()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end, { buffer = buf, desc = "Close clipboard editor" })
	vim.api.nvim_create_autocmd("WinClosed", {
		pattern = tostring(win),
		once = true,
		callback = function()
			if not saved and vim.api.nvim_buf_is_valid(buf) then
				vim.api.nvim_buf_delete(buf, { force = true })
			end
		end,
	})
end

local function open_picker()
	load_history()
	if #history == 0 then
		notify("Clipboard history is empty")
		return
	end
	local origin = vim.api.nvim_get_current_win()
	local query_buf = vim.api.nvim_create_buf(false, true)
	vim.bo[query_buf].buftype = "nofile"
	vim.bo[query_buf].bufhidden = "wipe"
	vim.bo[query_buf].swapfile = false
	vim.api.nvim_buf_set_lines(query_buf, 0, -1, false, { "" })
	local list_buf = vim.api.nvim_create_buf(false, true)
	vim.bo[list_buf].buftype = "nofile"
	vim.bo[list_buf].bufhidden = "wipe"
	vim.bo[list_buf].swapfile = false
	vim.bo[list_buf].modifiable = false
	local width = math.min(math.max(48, math.floor(vim.o.columns * 0.7)), math.max(1, vim.o.columns - 4))
	local list_height = math.min(math.max(8, #history + 1), math.max(1, vim.o.lines - vim.o.cmdheight - 8))
	local left = math.max(0, math.floor((vim.o.columns - width) / 2))
	local row = math.max(0, math.floor((vim.o.lines - list_height - 3) / 2))
	local list_win = vim.api.nvim_open_win(list_buf, false, {
		relative = "editor",
		row = row + 2,
		col = left,
		width = width,
		height = list_height,
		style = "minimal",
		border = "rounded",
		title = " Clipboard History ",
		title_pos = "center",
	})
	local query_win = vim.api.nvim_open_win(query_buf, true, {
		relative = "editor",
		row = row,
		col = left,
		width = width,
		height = 1,
		style = "minimal",
		border = "rounded",
		title = " Search ",
		title_pos = "left",
	})
	vim.wo[list_win].cursorline = true
	vim.wo[list_win].wrap = false
	vim.wo[list_win].number = false
	vim.wo[list_win].relativenumber = false
	vim.wo[list_win].signcolumn = "no"
	vim.wo[query_win].wrap = false
	vim.wo[query_win].number = false
	vim.wo[query_win].signcolumn = "no"
	local matches, selected, closed = {}, 1, false
	local function selected_item()
		return matches[selected]
	end
	local function render()
		matches = filtered_items(vim.api.nvim_buf_get_lines(query_buf, 0, 1, false)[1] or "")
		local lines = {}
		for _, item in ipairs(matches) do
			lines[#lines + 1] = summary(item, width)
		end
		if #lines == 0 then
			lines[1] = "No matching clipboard items"
		end
		local item = matches[selected]
		if item then
			lines[#lines + 1] = string.rep("─", math.max(1, width - 2))
			vim.list_extend(lines, preview_lines(item))
		end
		vim.bo[list_buf].modifiable = true
		vim.api.nvim_buf_set_lines(list_buf, 0, -1, false, lines)
		vim.bo[list_buf].modifiable = false
		if #matches > 0 then
			vim.api.nvim_win_set_cursor(list_win, { selected, 0 })
		end
	end
	local function close()
		if closed then
			return
		end
		closed = true
		for _, win in ipairs({ query_win, list_win }) do
			if vim.api.nvim_win_is_valid(win) then
				vim.api.nvim_win_close(win, true)
			end
		end
		if vim.api.nvim_win_is_valid(origin) then
			vim.api.nvim_set_current_win(origin)
		end
	end
	local function move(delta)
		if #matches == 0 then
			return
		end
		selected = math.max(1, math.min(#matches, selected + delta))
		render()
	end
	local function choose(action)
		local item = selected_item()
		if not item then
			return
		end
		if action == "delete" then
			for index, candidate in ipairs(history) do
				if candidate == item then
					table.remove(history, index)
					break
				end
			end
			save_history()
			selected = math.max(1, math.min(selected, #matches))
			render()
		elseif action == "edit" then
			open_editor(item, function()
				save_history()
				render()
			end)
		elseif action == "select" then
			vim.fn.setreg('"', item.contents, item.regtype)
			close()
		elseif action == "paste" or action == "paste_behind" or action == "replay" then
			close()
			vim.fn.setreg('"', item.contents, item.regtype)
			if vim.api.nvim_win_is_valid(origin) then
				vim.api.nvim_set_current_win(origin)
				vim.cmd("normal! " .. (action == "paste_behind" and "P" or "p"))
			end
		end
	end
	local function bind(modes, lhs, action, desc)
		vim.keymap.set(modes, lhs, function()
			choose(action)
		end, { buffer = query_buf, silent = true, nowait = true, desc = desc })
	end
	for _, key in ipairs({ "<Down>", "<C-n>" }) do
		vim.keymap.set({ "i", "n" }, key, function()
			move(1)
		end, { buffer = query_buf, silent = true, nowait = true })
	end
	for _, key in ipairs({ "<Up>" }) do
		vim.keymap.set({ "i", "n" }, key, function()
			move(-1)
		end, { buffer = query_buf, silent = true, nowait = true })
	end
	vim.keymap.set({ "i", "n" }, "<Esc>", close, { buffer = query_buf, silent = true, nowait = true })
	vim.keymap.set({ "i", "n" }, "<CR>", function()
		choose("select")
	end, { buffer = query_buf, silent = true, nowait = true })
	bind({ "i", "n" }, "<C-p>", "paste", "Paste before cursor")
	bind({ "i", "n" }, "<C-k>", "paste_behind", "Paste after cursor")
	bind({ "i", "n" }, "<C-q>", "replay", "Replay clipboard item")
	bind({ "i", "n" }, "<C-d>", "delete", "Delete clipboard item")
	bind({ "i", "n" }, "<C-e>", "edit", "Edit clipboard item")
	vim.keymap.set("n", "p", function()
		choose("paste_behind")
	end, { buffer = query_buf, silent = true, nowait = true })
	vim.keymap.set("n", "P", function()
		choose("paste")
	end, { buffer = query_buf, silent = true, nowait = true })
	vim.keymap.set("n", "q", function()
		choose("replay")
	end, { buffer = query_buf, silent = true, nowait = true })
	vim.keymap.set("n", "d", function()
		choose("delete")
	end, { buffer = query_buf, silent = true, nowait = true })
	vim.keymap.set("n", "e", function()
		choose("edit")
	end, { buffer = query_buf, silent = true, nowait = true })
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		buffer = query_buf,
		callback = function()
			selected = 1
			render()
		end,
	})
	for _, win in ipairs({ query_win, list_win }) do
		vim.api.nvim_create_autocmd("WinClosed", {
			pattern = tostring(win),
			once = true,
			callback = close,
		})
	end
	render()
	vim.cmd.startinsert()
end

---Register yank history capture and the standalone history picker.
function M.setup()
	load_history()
	local group = vim.api.nvim_create_augroup("NazoClipboardHistory", { clear = true })
	vim.api.nvim_create_autocmd("TextYankPost", {
		group = group,
		callback = function()
			register_yank(vim.v.event)
		end,
	})
	vim.api.nvim_create_user_command("Neoclip", open_picker, { desc = "Open clipboard history" })
	vim.api.nvim_create_user_command("ClipboardHistory", open_picker, { desc = "Open clipboard history" })
end

return M
