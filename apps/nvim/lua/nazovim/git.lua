local M = {}

local title = "NazoVim Git"
local sessions = {}

local function notify_error(message)
	vim.notify(message, vim.log.levels.ERROR, { title = title })
end

local function repository_root(path)
	if vim.fn.executable("git") ~= 1 then
		return nil
	end
	if path == nil then
		local name = vim.api.nvim_buf_get_name(0)
		path = name ~= "" and name or vim.fn.getcwd()
	end
	local directory = vim.fn.isdirectory(path) == 1 and path or vim.fs.dirname(path)
	local result = vim.system({ "git", "-C", directory, "rev-parse", "--show-toplevel" }, { text = true }):wait(2000)
	if result.code ~= 0 then
		return nil
	end
	return vim.trim(result.stdout)
end

local function run(root, arguments, timeout)
	local command = { "git", "-C", root }
	vim.list_extend(command, arguments)
	return vim.system(command, { text = true }):wait(timeout or 5000)
end

---Return the repository-relative path of a buffer, or nil when it is outside.
---@param root string
---@param path? string
---@return string?
function M.relative(root, path)
	if not root then
		return nil
	end
	path = path or vim.api.nvim_buf_get_name(0)
	if path == "" then
		return nil
	end
	local absolute = vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
	local prefix = vim.fs.normalize(root) .. "/"
	if absolute:sub(1, #prefix) ~= prefix then
		return nil
	end
	return absolute:sub(#prefix + 1)
end

---Return the parsed `git status --porcelain` entries.
---@param root? string
---@return { code: string, path: string }[]
function M.status_items(root)
	root = root or repository_root()
	if not root then
		return {}
	end
	local result = run(root, { "status", "--porcelain=v1", "-z" })
	if result.code ~= 0 then
		return {}
	end
	local items = {}
	local entries = vim.split(result.stdout or "", "\0", { trimempty = true })
	local index = 1
	while index <= #entries do
		local entry = entries[index]
		local code = entry:sub(1, 2)
		local path = entry:sub(4)
		-- Renames and copies store the previous path in the next field.
		if code:sub(1, 1) == "R" or code:sub(1, 1) == "C" then
			index = index + 1
		end
		items[#items + 1] = { code = code, path = path }
		index = index + 1
	end
	return items
end

local function scratch_buffer(name, filetype)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(buf, name .. "//" .. tostring(buf))
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].filetype = filetype
	return buf
end

local function show_scratch(name, filetype, lines)
	local buf = scratch_buffer(name, filetype)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_set_current_buf(buf)
	vim.keymap.set("n", "q", function()
		vim.cmd("bwipeout!")
	end, { buffer = buf, desc = "Close" })
	return buf
end

---Show `git diff` output for a path, or the whole worktree.
---@param path? string
---@param root? string
---@param staged? boolean
---@return string
function M.show_diff(path, root, staged)
	root = root or repository_root()
	if not root then
		notify_error("Current directory is not inside a Git repository")
		return ""
	end
	path = path or M.relative(root)
	local arguments = { "diff" }
	if staged then
		arguments[#arguments + 1] = "--cached"
	end
	if path then
		vim.list_extend(arguments, { "--", path })
	end
	local result = run(root, arguments)
	if result.code ~= 0 then
		notify_error("git diff failed" .. (result.stderr ~= "" and (": " .. vim.trim(result.stderr)) or ""))
		return ""
	end
	local output = result.stdout or ""
	local lines = vim.split(output, "\n", { plain = true })
	if #lines == 0 or (output == "") then
		vim.notify("No changes", vim.log.levels.INFO, { title = title })
		return ""
	end
	show_scratch("NazoGitDiff", "diff", lines)
	return output
end

---Stage a path (or the current buffer when omitted).
---@param path? string
---@param root? string
---@return boolean
function M.stage(path, root)
	root = root or repository_root()
	if not root then
		notify_error("Current directory is not inside a Git repository")
		return false
	end
	path = path or M.relative(root)
	if not path then
		notify_error("This buffer is not inside the Git repository")
		return false
	end
	local result = run(root, { "add", "--", path })
	if result.code ~= 0 then
		notify_error("git add failed" .. (result.stderr ~= "" and (": " .. vim.trim(result.stderr)) or ""))
		return false
	end
	return true
end

---Unstage a path (or the current buffer when omitted).
---@param path? string
---@param root? string
---@return boolean
function M.unstage(path, root)
	root = root or repository_root()
	if not root then
		notify_error("Current directory is not inside a Git repository")
		return false
	end
	path = path or M.relative(root)
	if not path then
		notify_error("This buffer is not inside the Git repository")
		return false
	end
	local result = run(root, { "restore", "--staged", "--", path })
	if result.code ~= 0 then
		result = run(root, { "reset", "-q", "HEAD", "--", path })
	end
	if result.code ~= 0 then
		notify_error("git restore failed" .. (result.stderr ~= "" and (": " .. vim.trim(result.stderr)) or ""))
		return false
	end
	return true
end

local function status_lines(items)
	local lines = { "Git status: " .. #items .. " change(s)", "" }
	for _, item in ipairs(items) do
		lines[#lines + 1] = item.code .. " " .. item.path
	end
	if #items == 0 then
		lines[#lines + 1] = "  (clean)"
	end
	return lines
end

local function status_item(buf, row)
	local session = sessions[buf]
	if not session then
		return nil
	end
	return session.items[row - 2]
end

local function refresh_status(buf)
	local session = sessions[buf]
	if not session then
		return
	end
	session.items = M.status_items(session.root)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, status_lines(session.items))
end

local function open_status_entry(buf)
	local item = status_item(buf, vim.api.nvim_win_get_cursor(0)[1])
	local session = sessions[buf]
	if not item or not session then
		return
	end
	vim.cmd("edit " .. vim.fn.fnameescape(session.root .. "/" .. item.path))
end

---Open the interactive status buffer.
---@param root? string
---@return integer? buf
function M.show_status(root)
	root = root or repository_root()
	if not root then
		notify_error("Current directory is not inside a Git repository")
		return
	end
	local buf = scratch_buffer("NazoGitStatus", "nazogitstatus")
	local session = { root = root, items = M.status_items(root) }
	sessions[buf] = session
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, status_lines(session.items))
	vim.api.nvim_set_current_buf(buf)

	local opts = { buffer = buf, nowait = true }
	vim.keymap.set("n", "<CR>", function()
		open_status_entry(buf)
	end, vim.tbl_extend("force", opts, { desc = "Open file" }))
	vim.keymap.set("n", "s", function()
		local item = status_item(buf, vim.api.nvim_win_get_cursor(0)[1])
		if item and M.stage(item.path, session.root) then
			refresh_status(buf)
		end
	end, vim.tbl_extend("force", opts, { desc = "Stage file" }))
	vim.keymap.set("n", "u", function()
		local item = status_item(buf, vim.api.nvim_win_get_cursor(0)[1])
		if item and M.unstage(item.path, session.root) then
			refresh_status(buf)
		end
	end, vim.tbl_extend("force", opts, { desc = "Unstage file" }))
	vim.keymap.set("n", "d", function()
		local item = status_item(buf, vim.api.nvim_win_get_cursor(0)[1])
		if item then
			M.show_diff(item.path, session.root)
		end
	end, vim.tbl_extend("force", opts, { desc = "Diff file" }))
	vim.keymap.set("n", "R", function()
		refresh_status(buf)
	end, vim.tbl_extend("force", opts, { desc = "Refresh" }))
	vim.keymap.set("n", "q", function()
		vim.cmd("bwipeout!")
	end, vim.tbl_extend("force", opts, { desc = "Close" }))
	return buf
end

---Return the parsed `git log --oneline` entries.
---@param root? string
---@param path? string
---@return { hash: string, subject: string }[]
function M.log_entries(root, path)
	root = root or repository_root()
	if not root then
		return {}
	end
	local arguments = { "log", "--oneline", "--decorate", "-n", "100" }
	if path then
		vim.list_extend(arguments, { "--", path })
	end
	local result = run(root, arguments)
	if result.code ~= 0 then
		return {}
	end
	local entries = {}
	for _, line in ipairs(vim.split(result.stdout or "", "\n", { trimempty = true })) do
		local hash, subject = line:match("^(%S+)%s+(.*)$")
		if hash then
			entries[#entries + 1] = { hash = hash, subject = subject }
		end
	end
	return entries
end

---Show a commit with its stat and patch.
---@param hash string
---@param root? string
---@return string
function M.show_commit(hash, root)
	root = root or repository_root()
	if not root then
		notify_error("Current directory is not inside a Git repository")
		return ""
	end
	local result = run(root, { "show", "--stat", "--patch", hash }, 10000)
	if result.code ~= 0 then
		notify_error("git show failed" .. (result.stderr ~= "" and (": " .. vim.trim(result.stderr)) or ""))
		return ""
	end
	local output = result.stdout or ""
	show_scratch("NazoGitShow", "diff", vim.split(output, "\n", { plain = true }))
	return output
end

---Pick a commit from the log and show it.
function M.show_log()
	local root = repository_root()
	if not root then
		notify_error("Current directory is not inside a Git repository")
		return
	end
	local entries = M.log_entries(root, M.relative(root))
	if #entries == 0 then
		vim.notify("No commits found", vim.log.levels.INFO, { title = title })
		return
	end
	vim.ui.select(entries, {
		prompt = "Git log",
		format_item = function(entry)
			return entry.hash .. " " .. entry.subject
		end,
	}, function(entry)
		if entry then
			M.show_commit(entry.hash, root)
		end
	end)
end

---Return the `git blame` line for the current cursor position.
---@param root? string
---@return string
function M.blame_line(root)
	root = root or repository_root()
	if not root then
		return ""
	end
	local path = M.relative(root)
	if not path then
		return ""
	end
	local line = vim.api.nvim_win_get_cursor(0)[1]
	local result = run(root, { "blame", "-L", line .. "," .. line, "--porcelain", "--", path })
	if result.code ~= 0 then
		return ""
	end
	local output = result.stdout or ""
	local hash = output:match("^(%x+)")
	local author = output:match("\nauthor ([^\n]*)")
	local summary = output:match("\nsummary ([^\n]*)")
	if not hash then
		return ""
	end
	return table.concat({ hash:sub(1, 8), author or "?", summary or "" }, " ")
end

---Show the blame for the current line in a floating window.
function M.show_blame()
	local text = M.blame_line()
	if text == "" then
		vim.notify("No blame information for this line", vim.log.levels.WARN, { title = title })
		return
	end
	local buf = scratch_buffer("NazoGitBlame", "nazogitblame")
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(text, "\n", { plain = true }))
	local width = math.min(#text + 2, math.max(20, vim.o.columns - 4))
	local win = vim.api.nvim_open_win(buf, false, {
		relative = "cursor",
		row = 1,
		col = 0,
		width = width,
		height = 1,
		style = "minimal",
		border = "rounded",
		title = " Git blame ",
		title_pos = "center",
	})
	vim.keymap.set("n", "q", function()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end, { buffer = buf, desc = "Close" })
end

local function expand_arguments(arguments)
	local expanded = {}
	for _, argument in ipairs(arguments) do
		if argument == "%" then
			local root = repository_root()
			expanded[#expanded + 1] = (root and M.relative(root)) or vim.fn.expand("%")
		else
			expanded[#expanded + 1] = argument
		end
	end
	return expanded
end

---Run `git <arguments>` and show the output in a scratch buffer.
---@param arguments string[]
function M.command(arguments)
	local root = repository_root()
	if not root then
		notify_error("Current directory is not inside a Git repository")
		return
	end
	if #arguments == 0 then
		M.show_status()
		return
	end
	local result = run(root, expand_arguments(arguments), 20000)
	local output = (result.stdout or "") .. (result.stderr or "")
	if result.code ~= 0 then
		vim.notify(vim.trim(output), vim.log.levels.ERROR, { title = title })
		return
	end
	show_scratch("NazoGitOutput", "git", vim.split(output, "\n", { plain = true }))
end

function M.setup()
	vim.api.nvim_create_user_command("Git", function(command)
		M.command(command.fargs)
	end, { nargs = "*", desc = "Run a git command" })
	vim.api.nvim_create_user_command("NazoGitStatus", M.show_status, { desc = "Show the Git status" })
	vim.api.nvim_create_user_command("NazoGitStage", function(command)
		M.stage(command.args ~= "" and command.args or nil)
	end, { nargs = "?", desc = "Stage a file" })
	vim.api.nvim_create_user_command("NazoGitUnstage", function(command)
		M.unstage(command.args ~= "" and command.args or nil)
	end, { nargs = "?", desc = "Unstage a file" })
	vim.api.nvim_create_user_command("NazoGitDiff", function(command)
		M.show_diff(command.args ~= "" and command.args or nil)
	end, { nargs = "?", desc = "Show the Git diff" })
	vim.api.nvim_create_user_command("NazoGitLog", M.show_log, { desc = "Browse the Git log" })
	vim.api.nvim_create_user_command("NazoGitBlame", M.show_blame, { desc = "Show the blame for this line" })

	vim.keymap.set("n", "<leader>gs", M.show_status, { desc = "Git status" })
	vim.keymap.set("n", "<leader>ga", function()
		local root = repository_root()
		local path = M.relative(root)
		if M.stage(path, root) then
			vim.notify("Staged " .. path, vim.log.levels.INFO, { title = title })
		end
	end, { desc = "Stage current file" })
	vim.keymap.set("n", "<leader>gu", function()
		local root = repository_root()
		local path = M.relative(root)
		if M.unstage(path, root) then
			vim.notify("Unstaged " .. path, vim.log.levels.INFO, { title = title })
		end
	end, { desc = "Unstage current file" })
	vim.keymap.set("n", "<leader>gl", M.show_log, { desc = "Git log" })
end

return M
