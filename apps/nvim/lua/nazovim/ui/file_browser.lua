local M = {}

local icons = require("nazovim.ui.icons")
local uv = vim.uv
local states = {}
local namespace = vim.api.nvim_create_namespace("NazoFileBrowser")
local next_buffer_id = 0

local function notify_error(message)
	vim.notify(message, vim.log.levels.ERROR, { title = "NazoVim Files" })
end

local function normalize(path)
	return vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
end

local function read_git_status(directory, callback)
	local root = vim.fs.root(directory, ".git")
	if not root then
		callback({})
		return
	end
	vim.system({ "git", "-C", root, "status", "--porcelain=v1", "-z", "--untracked-files=all" }, {
		text = true,
	}, function(result)
		local statuses = {}
		if result.code == 0 then
			local records = vim.split(result.stdout or "", "\0", { plain = true, trimempty = true })
			local index = 1
			while index <= #records do
				local record = records[index]
				local code, relative = record:sub(1, 2), record:sub(4)
				if relative ~= "" then
					statuses[normalize(root .. "/" .. relative)] = code
				end
				index = index + ((code:find("R", 1, true) or code:find("C", 1, true)) and 2 or 1)
			end
		end
		vim.schedule(function()
			callback(statuses)
		end)
	end)
end

local function collect(directory, show_hidden)
	local entries, handle = {}, uv.fs_scandir(directory)
	if not handle then
		return nil, "cannot read directory: " .. directory
	end
	while true do
		local name, kind = uv.fs_scandir_next(handle)
		if not name then
			break
		end
		if show_hidden or not name:match("^%.") then
			local path = directory .. "/" .. name
			local stat = kind == "link" and uv.fs_stat(path) or nil
			entries[#entries + 1] = {
				name = name,
				path = path,
				is_link = kind == "link",
				is_dir = kind == "directory" or (stat and stat.type == "directory") or false,
			}
		end
	end
	table.sort(entries, function(left, right)
		if left.is_dir ~= right.is_dir then
			return left.is_dir
		end
		return left.name:lower() < right.name:lower()
	end)
	return entries
end

local function render(state, preferred_path)
	if not vim.api.nvim_buf_is_valid(state.buf) then
		return
	end
	local entries, err = collect(state.directory, state.show_hidden)
	if not entries then
		notify_error(err)
		return
	end
	state.entries = entries
	local lines = { "  " .. state.directory, "", "  .." }
	state.line_items = { [3] = { path = vim.fs.dirname(state.directory), is_dir = true } }
	local selected_line = preferred_path and 3 or nil
	for _, entry in ipairs(entries) do
		local status = state.git_status[normalize(entry.path)]
		local marker = entry.is_dir and "▸ " or "  "
		local suffix = entry.is_dir and "/" or ""
		local git = status and ("  [" .. status .. "]") or ""
		local icon = entry.is_dir and "" or (icons.get_icon(entry.name) .. " ")
		lines[#lines + 1] = marker .. icon .. entry.name .. suffix .. git
		state.line_items[#lines] = entry
		if preferred_path and normalize(entry.path) == preferred_path then
			selected_line = #lines
		end
	end
	vim.bo[state.buf].modifiable = true
	vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
	vim.api.nvim_buf_clear_namespace(state.buf, namespace, 0, -1)
	for line, entry in pairs(state.line_items) do
		if entry.is_dir then
			vim.api.nvim_buf_add_highlight(state.buf, namespace, "Directory", line - 1, 0, -1)
		end
	end
	vim.bo[state.buf].modifiable = false
	if state.win and vim.api.nvim_win_is_valid(state.win) and vim.api.nvim_win_get_buf(state.win) == state.buf then
		if selected_line then
			vim.api.nvim_win_set_cursor(state.win, { selected_line, 0 })
		else
			vim.api.nvim_win_set_cursor(state.win, { math.min(3, #lines), 0 })
		end
	end
end

local function refresh(state, preferred_path)
	local directory = state.directory
	read_git_status(directory, function(statuses)
		if states[state.buf] == state and state.directory == directory and vim.api.nvim_buf_is_valid(state.buf) then
			state.git_status = statuses
			render(state, preferred_path)
		end
	end)
	render(state, preferred_path)
end

local function current_state()
	return states[vim.api.nvim_get_current_buf()]
end

local function open_directory(state, directory, preferred_path)
	directory = normalize(directory)
	local stat = uv.fs_stat(directory)
	if not stat or stat.type ~= "directory" then
		return notify_error("not a directory: " .. directory)
	end
	state.directory = directory
	state.git_status = {}
	vim.api.nvim_buf_set_name(state.buf, "NazoFiles://" .. directory .. "#" .. state.id)
	refresh(state, preferred_path and normalize(preferred_path) or nil)
end

local function open_entry(state, mode)
	local line = vim.api.nvim_win_get_cursor(0)[1]
	local entry = state.line_items[line]
	if not entry then
		return
	end
	if entry.is_dir then
		return open_directory(state, entry.path)
	end
	if mode == "vsplit" then
		vim.cmd.vsplit({ args = { entry.path } })
	elseif mode == "split" then
		vim.cmd.split({ args = { entry.path } })
	elseif mode == "tab" then
		vim.cmd.tabedit({ args = { entry.path } })
	else
		vim.cmd.edit({ args = { entry.path } })
	end
end

local function parent(state)
	local directory = vim.fs.dirname(state.directory)
	if directory and directory ~= state.directory then
		open_directory(state, directory, state.directory)
	end
end

local function create_entry(state)
	vim.ui.input({ prompt = "Create file or directory (append / for directory): " }, function(value)
		if not value or value == "" then
			return
		end
		local directory = value:sub(-1) == "/"
		local target = normalize(state.directory .. "/" .. value)
		if uv.fs_lstat(target) then
			return notify_error("already exists: " .. target)
		end
		local ok, err
		if directory then
			ok, err = uv.fs_mkdir(target, 493)
		else
			local fd
			fd, err = uv.fs_open(target, "wx", 420)
			ok = fd ~= nil
			if fd then
				uv.fs_close(fd)
			end
		end
		if not ok then
			return notify_error(err or "could not create entry")
		end
		refresh(state, target)
	end)
end

local function rename_entry(state)
	local entry = state.line_items[vim.api.nvim_win_get_cursor(0)[1]]
	if not entry then
		return
	end
	vim.ui.input({ prompt = "Rename to: ", default = entry.name }, function(value)
		if not value or value == "" or value == entry.name then
			return
		end
		local target = normalize(state.directory .. "/" .. value)
		if uv.fs_lstat(target) then
			return notify_error("destination already exists: " .. target)
		end
		local ok, err = uv.fs_rename(entry.path, target)
		if not ok then
			return notify_error(err or "could not rename entry")
		end
		refresh(state, target)
	end)
end

local function remove_path(path)
	local stat = uv.fs_lstat(path)
	if not stat then
		return nil, "path no longer exists: " .. path
	end
	if stat.type ~= "directory" then
		return uv.fs_unlink(path)
	end
	local handle = uv.fs_scandir(path)
	if not handle then
		return nil, "cannot read directory: " .. path
	end
	while true do
		local name = uv.fs_scandir_next(handle)
		if not name then
			break
		end
		local ok, err = remove_path(path .. "/" .. name)
		if not ok then
			return nil, err
		end
	end
	return uv.fs_rmdir(path)
end

local function delete_entry(state)
	local entry = state.line_items[vim.api.nvim_win_get_cursor(0)[1]]
	if not entry then
		return
	end
	vim.ui.input({ prompt = "Delete " .. entry.name .. "? Type yes to confirm: " }, function(answer)
		if answer ~= "yes" then
			return
		end
		local ok, err = remove_path(entry.path)
		if not ok then
			return notify_error(err or "could not delete entry")
		end
		refresh(state)
	end)
end

local function copy_path(source, target)
	local stat = uv.fs_lstat(source)
	if not stat then
		return nil, "source no longer exists: " .. source
	end
	if stat.type == "link" then
		local destination, read_err = uv.fs_readlink(source)
		if not destination then
			return nil, read_err
		end
		return uv.fs_symlink(destination, target)
	end
	if stat.type ~= "directory" then
		return uv.fs_copyfile(source, target)
	end
	local ok, err = uv.fs_mkdir(target, stat.mode % 512)
	if not ok then
		return nil, err
	end
	local handle = uv.fs_scandir(source)
	if not handle then
		return nil, "cannot read directory: " .. source
	end
	while true do
		local name = uv.fs_scandir_next(handle)
		if not name then
			break
		end
		local child_ok, child_err = copy_path(source .. "/" .. name, target .. "/" .. name)
		if not child_ok then
			return nil, child_err
		end
	end
	return true
end

local function copy_entry(state)
	local entry = state.line_items[vim.api.nvim_win_get_cursor(0)[1]]
	if not entry then
		return
	end
	vim.ui.input({ prompt = "Copy to: ", default = entry.name .. ".copy" }, function(value)
		if not value or value == "" then
			return
		end
		local target = normalize(state.directory .. "/" .. value)
		if uv.fs_lstat(target) then
			return notify_error("destination already exists: " .. target)
		end
		local ok, err = copy_path(entry.path, target)
		if not ok then
			return notify_error(err or "could not copy entry")
		end
		refresh(state, target)
	end)
end

local function preview_entry(state)
	local entry = state.line_items[vim.api.nvim_win_get_cursor(0)[1]]
	if not entry or entry.is_dir then
		return
	end
	local lines = vim.fn.readfile(entry.path, "", 120)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, #lines > 0 and lines or { "(empty file)" })
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].filetype = vim.filetype.match({ filename = entry.path }) or ""
	local height = math.max(4, math.min(#lines, math.floor(vim.o.lines * 0.6)))
	local width = math.max(30, math.min(100, math.floor(vim.o.columns * 0.6)))
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		style = "minimal",
		border = "rounded",
		row = math.floor((vim.o.lines - height) / 2) - 1,
		col = math.floor((vim.o.columns - width) / 2),
		height = height,
		width = width,
		title = " " .. entry.name .. " ",
	})
	vim.keymap.set("n", "q", function()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end, { buffer = buf, desc = "Close file preview" })
end

local function register_mappings(buf)
	local function map(lhs, callback, desc)
		vim.keymap.set("n", lhs, callback, { buffer = buf, desc = desc, nowait = true })
	end
	map("<CR>", function()
		open_entry(current_state())
	end, "Open file or directory")
	map("-", function()
		parent(current_state())
	end, "Open parent directory")
	map("<BS>", function()
		parent(current_state())
	end, "Open parent directory")
	map("<Esc>", function()
		vim.api.nvim_buf_delete(buf, { force = true })
	end, "Close file browser")
	map("<C-l>", function()
		local state = current_state()
		refresh(state)
	end, "Refresh directory")
	map("g.", function()
		local state = current_state()
		state.show_hidden = not state.show_hidden
		render(state)
	end, "Toggle hidden files")
	map("<C-p>", function()
		preview_entry(current_state())
	end, "Preview file")
	map("a", function()
		create_entry(current_state())
	end, "Create file or directory")
	map("r", function()
		rename_entry(current_state())
	end, "Rename file or directory")
	map("d", function()
		delete_entry(current_state())
	end, "Delete file or directory recursively")
	map("c", function()
		copy_entry(current_state())
	end, "Copy file or directory")
	map("y", function()
		local entry = current_state().line_items[vim.api.nvim_win_get_cursor(0)[1]]
		if entry then
			vim.fn.setreg('"', entry.path)
			vim.notify("Copied path: " .. entry.path)
		end
	end, "Yank path")
	map("_", function()
		local state = current_state()
		open_directory(state, vim.fn.getcwd())
	end, "Open current working directory")
	map("`", function()
		vim.cmd.cd({ args = { current_state().directory } })
	end, "Change working directory")
	map("~", function()
		vim.cmd.tcd({ args = { current_state().directory } })
	end, "Change tab working directory")
	map("<C-s>", function()
		open_entry(current_state(), "vsplit")
	end, "Open in vertical split")
	map("<C-h>", function()
		open_entry(current_state(), "split")
	end, "Open in horizontal split")
	map("<C-t>", function()
		open_entry(current_state(), "tab")
	end, "Open in tab")
	map("gx", function()
		local entry = current_state().line_items[vim.api.nvim_win_get_cursor(0)[1]]
		if entry then
			vim.ui.open(entry.path)
		end
	end, "Open with system application")
	map("?", function()
		vim.notify(
			"Enter open · - parent · g. hidden · <C-p> preview · a create · r rename · d delete · c copy · y path",
			vim.log.levels.INFO,
			{ title = "NazoVim Files" }
		)
	end, "Show file browser help")
end

function M.open(path)
	path = normalize(path or vim.fn.getcwd())
	local stat = uv.fs_stat(path)
	local directory = stat and stat.type == "directory" and path or vim.fs.dirname(path)
	local buf = vim.api.nvim_create_buf(false, true)
	next_buffer_id = next_buffer_id + 1
	local state = {
		buf = buf,
		id = next_buffer_id,
		directory = directory,
		show_hidden = false,
		git_status = {},
		line_items = {},
	}
	states[buf] = state
	vim.api.nvim_buf_set_name(buf, "NazoFiles://" .. directory .. "#" .. state.id)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "hide"
	vim.bo[buf].swapfile = false
	vim.bo[buf].filetype = "nazofiles"
	vim.bo[buf].modifiable = false
	register_mappings(buf)
	vim.api.nvim_create_autocmd("BufWipeout", {
		buffer = buf,
		once = true,
		callback = function()
			states[buf] = nil
		end,
	})
	vim.api.nvim_set_current_buf(buf)
	state.win = vim.api.nvim_get_current_win()
	refresh(state, stat and stat.type ~= "directory" and path or nil)
end

function M.setup()
	vim.keymap.set("n", "<leader>m", function()
		M.open(vim.fn.getcwd())
	end, { desc = "Open file browser" })
	vim.keymap.set("n", "<leader>n", function()
		M.open(vim.fn.getcwd())
	end, { desc = "Open file browser" })
	vim.api.nvim_create_user_command("NazoFiles", function(command)
		M.open(command.args ~= "" and command.args or vim.fn.getcwd())
	end, { nargs = "?", complete = "dir", desc = "Browse files in a directory" })
end

return M
