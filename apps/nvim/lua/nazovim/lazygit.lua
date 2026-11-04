local M = {}

local active = {}

local function repository_root(buf)
	local path = vim.api.nvim_buf_get_name(buf)
	local directory = path ~= "" and vim.fs.dirname(path) or vim.fn.getcwd()
	if vim.fn.executable("git") ~= 1 then
		return nil
	end
	local result = vim.system({ "git", "-C", directory, "rev-parse", "--show-toplevel" }, { text = true }):wait(1000)
	return result and result.code == 0 and vim.trim(result.stdout) or nil
end

---Close the floating LazyGit terminal and stop its process.
function M.close()
	for buf, session in pairs(active) do
		active[buf] = nil
		if session.job and session.job > 0 then
			pcall(vim.fn.jobstop, session.job)
		end
		if session.win and vim.api.nvim_win_is_valid(session.win) then
			vim.api.nvim_win_close(session.win, true)
		end
		if vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_buf_delete(buf, { force = true })
		end
		active[buf] = nil
	end
end

---Open LazyGit in a centered floating terminal for the current repository.
function M.open(arguments)
	if vim.fn.executable("lazygit") ~= 1 then
		vim.notify("The lazygit executable is required", vim.log.levels.ERROR, { title = "NazoVim Git" })
		return
	end
	local root = repository_root(vim.api.nvim_get_current_buf())
	if not root then
		vim.notify("Current directory is not inside a Git repository", vim.log.levels.ERROR, { title = "NazoVim Git" })
		return
	end
	M.close()
	local width = math.max(1, math.min(vim.o.columns - 2, math.floor(vim.o.columns * 0.9)))
	local height = math.max(1, math.min(vim.o.lines - 2, math.floor(vim.o.lines * 0.85)))
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
		col = math.max(0, math.floor((vim.o.columns - width) / 2)),
		style = "minimal",
		border = "rounded",
		title = " LazyGit ",
		title_pos = "center",
	})
	local session = { win = win }
	active[buf] = session
	vim.api.nvim_create_autocmd("BufWipeout", {
		buffer = buf,
		once = true,
		callback = function()
			if active[buf] == session then
				active[buf] = nil
				if session.job and session.job > 0 then
					pcall(vim.fn.jobstop, session.job)
				end
			end
		end,
	})
	local command = { "lazygit" }
	if type(arguments) == "table" then
		vim.list_extend(command, arguments)
	end
	local job = vim.fn.termopen(command, {
		cwd = root,
		on_exit = function()
			vim.schedule(function()
				if active[buf] ~= session then
					return
				end
				active[buf] = nil
				if session.win and vim.api.nvim_win_is_valid(session.win) then
					vim.api.nvim_win_close(session.win, true)
				end
				if vim.api.nvim_buf_is_valid(buf) then
					vim.api.nvim_buf_delete(buf, { force = true })
				end
			end)
		end,
	})
	if job <= 0 then
		active[buf] = nil
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
		vim.notify("Could not start lazygit", vim.log.levels.ERROR, { title = "NazoVim Git" })
		return
	end
	session.job = job
	vim.keymap.set("t", "<Esc>", function()
		M.close()
	end, { buffer = buf, desc = "Close LazyGit" })
	vim.keymap.set("n", "q", function()
		M.close()
	end, { buffer = buf, desc = "Close LazyGit" })
	vim.cmd.startinsert()
end

---Register LazyGit commands and mapping.
function M.setup()
	vim.keymap.set("n", "<leader>gg", M.open, { desc = "Open LazyGit" })
	vim.api.nvim_create_user_command("NazoLazygit", function(command)
		M.open(vim.split(command.args, "%s+", { trimempty = true }))
	end, { nargs = "*", desc = "Open LazyGit in the current repository" })
	vim.api.nvim_create_user_command("LazyGit", function(command)
		M.open(vim.split(command.args, "%s+", { trimempty = true }))
	end, { nargs = "*", desc = "Open LazyGit in the current repository" })
end

return M
