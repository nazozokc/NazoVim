local M = {}

local review_buffers = {}
local conflict_maps = {}
local conflict_keys = { "<leader>co", "<leader>ct", "<leader>ca", "dx" }

local function git_root(path)
	if vim.fn.executable("git") ~= 1 then
		return nil
	end
	path = path or vim.fn.getcwd()
	local directory = vim.fn.isdirectory(path) == 1 and path or vim.fs.dirname(path)
	local result = vim.system({ "git", "-C", directory, "rev-parse", "--show-toplevel" }, { text = true }):wait(1000)
	return result and result.code == 0 and vim.trim(result.stdout) or nil
end

local function run_git(root, arguments, callback)
	local command = { "git", "-C", root }
	vim.list_extend(command, arguments)
	vim.system(command, { text = true }, callback)
end

local function notify_error(result, operation)
	local detail = vim.trim(result.stderr or "")
	vim.notify(
		operation .. " failed" .. (detail ~= "" and (": " .. detail) or ""),
		vim.log.levels.ERROR,
		{ title = "NazoVim Git" }
	)
end

local function close_buffer(buf)
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	for _, win in ipairs(vim.fn.win_findbuf(buf)) do
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end
	vim.api.nvim_buf_delete(buf, { force = true })
	review_buffers[buf] = nil
end

---Close the active Git review diff buffer.
function M.close(quiet)
	local closed = false
	for buf in pairs(review_buffers) do
		close_buffer(buf)
		closed = true
	end
	if not closed and not quiet then
		vim.notify("No Git review view is open", vim.log.levels.INFO, { title = "NazoVim Git" })
	end
end

local function show_diff(title, content)
	M.close(true)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(buf, "NazoGitReview://" .. tostring(os.time()))
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].filetype = "diff"
	local lines = vim.split(content, "\n", { plain = true })
	if lines[#lines] == "" then
		table.remove(lines)
	end
	if #lines == 0 then
		lines = { "No changes" }
	end
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	review_buffers[buf] = true
	vim.cmd("botright 14split")
	local win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(win, buf)
	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].wrap = false
	vim.wo[win].signcolumn = "no"
	vim.api.nvim_win_set_cursor(win, { 1, 0 })
	vim.api.nvim_buf_set_name(buf, "NazoGitReview://" .. title:gsub("[^%w_.-]", "_"))
	vim.keymap.set("n", "q", M.close, { buffer = buf, desc = "Close Git review" })
	vim.keymap.set("n", "<Esc>", M.close, { buffer = buf, desc = "Close Git review" })
end

local function relative_path(root, path)
	return vim.fs.relpath(root, path) or path
end

local function show_file_diff(root, path, title)
	run_git(root, { "diff", "--no-ext-diff", "--no-renames", "--patch", "HEAD", "--", path }, function(result)
		vim.schedule(function()
			if result.code ~= 0 then
				notify_error(result, "git diff")
			elseif vim.trim(result.stdout) == "" then
				vim.notify("No tracked changes for " .. path, vim.log.levels.INFO, { title = "NazoVim Git" })
			else
				show_diff(title, result.stdout)
			end
		end)
	end)
end

---List changed files and display the selected file's patch.
function M.open()
	local root = git_root(vim.api.nvim_buf_get_name(0))
	if not root then
		vim.notify("Current directory is not inside a Git repository", vim.log.levels.ERROR, { title = "NazoVim Git" })
		return
	end
	run_git(root, { "status", "--short", "--no-renames", "--untracked-files=no", "-z" }, function(result)
		vim.schedule(function()
			if result.code ~= 0 then
				notify_error(result, "git status")
				return
			end
			local paths = {}
			for line in result.stdout:gmatch("[^%z]+") do
				local path = line:sub(4)
				if path ~= "" then
					paths[#paths + 1] = path
				end
			end
			if #paths == 0 then
				vim.notify("No tracked Git changes", vim.log.levels.INFO, { title = "NazoVim Git" })
				return
			end
			vim.ui.select(paths, { prompt = "Review changed file" }, function(path)
				if path then
					show_file_diff(root, path, path)
				end
			end)
		end)
	end)
end

local function parse_commits(output)
	local commits = {}
	for line in output:gmatch("[^\n]+") do
		local hash, short, subject = line:match("^([^\t]+)\t([^\t]+)\t(.*)$")
		if hash then
			commits[#commits + 1] = { hash = hash, label = short .. "  " .. subject }
		end
	end
	return commits
end

local function history(file, root_path)
	local root = git_root(root_path or file)
	if not root then
		vim.notify("Current file is not inside a Git repository", vim.log.levels.ERROR, { title = "NazoVim Git" })
		return
	end
	local path = file and relative_path(root, file)
	local arguments = { "log", "--format=%H%x09%h%x09%s", "-n", "100" }
	if path then
		vim.list_extend(arguments, { "--follow", "--", path })
	end
	run_git(root, arguments, function(result)
		vim.schedule(function()
			if result.code ~= 0 then
				notify_error(result, "git log")
				return
			end
			local commits = parse_commits(result.stdout)
			if #commits == 0 then
				vim.notify("No Git history found", vim.log.levels.INFO, { title = "NazoVim Git" })
				return
			end
			vim.ui.select(commits, {
				prompt = path and ("File history: " .. path) or "Branch history",
				format_item = function(commit)
					return commit.label
				end,
			}, function(commit)
				if not commit then
					return
				end
				local show = { "show", "--no-ext-diff", "--format=fuller", "--patch", commit.hash }
				if path then
					vim.list_extend(show, { "--", path })
				end
				run_git(root, show, function(patch_result)
					vim.schedule(function()
						if patch_result.code ~= 0 then
							notify_error(patch_result, "git show")
						else
							show_diff(commit.label, patch_result.stdout)
						end
					end)
				end)
			end)
		end)
	end)
end

---Select and preview the current file's commit history.
function M.file_history()
	local file = vim.api.nvim_buf_get_name(0)
	if file == "" then
		vim.notify("Current buffer has no file", vim.log.levels.WARN, { title = "NazoVim Git" })
		return
	end
	history(file)
end

---Select and preview recent commits in the current branch.
function M.branch_history()
	history(nil, vim.api.nvim_buf_get_name(0))
end

local function conflict_range(buf, row)
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local start_row, base_row, separator_row, end_row
	for index = row, 1, -1 do
		if lines[index]:match("^<<<<<<<") then
			start_row = index
			break
		end
	end
	if not start_row then
		return nil
	end
	for index = start_row + 1, #lines do
		if not separator_row and lines[index]:match("^|||||||") then
			base_row = index
		elseif lines[index]:match("^=======") then
			separator_row = index
		elseif lines[index]:match("^>>>>>>>") then
			end_row = index
			break
		end
	end
	if not separator_row or not end_row or row > end_row then
		return nil
	end
	return {
		lines = lines,
		start_row = start_row,
		base_row = base_row,
		separator_row = separator_row,
		end_row = end_row,
	}
end

local function choose_conflict(choice)
	local buf = vim.api.nvim_get_current_buf()
	local row = vim.api.nvim_win_get_cursor(0)[1]
	local conflict = conflict_range(buf, row)
	if not conflict then
		vim.notify("Cursor is not inside a merge conflict", vim.log.levels.INFO, { title = "NazoVim Git" })
		return
	end
	local ours_end = (conflict.base_row or conflict.separator_row) - 1
	local ours = vim.list_slice(conflict.lines, conflict.start_row + 1, ours_end)
	local theirs = vim.list_slice(conflict.lines, conflict.separator_row + 1, conflict.end_row - 1)
	local replacement = {}
	if choice == "ours" then
		replacement = ours
	elseif choice == "theirs" then
		replacement = theirs
	elseif choice == "all" then
		vim.list_extend(replacement, ours)
		vim.list_extend(replacement, theirs)
	elseif choice ~= "none" then
		vim.notify("Choice must be ours, theirs, all, or none", vim.log.levels.ERROR, { title = "NazoVim Git" })
		return
	end
	vim.api.nvim_buf_set_lines(buf, conflict.start_row - 1, conflict.end_row, false, replacement)
end

---Choose the current merge conflict's ours, theirs, both, or neither side.
function M.choose_conflict(choice)
	choose_conflict(choice)
end

local function update_conflict_maps(buf)
	if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= "" then
		return
	end
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local has_conflict = false
	for _, line in ipairs(lines) do
		if line:match("^<<<<<<<") then
			has_conflict = true
			break
		end
	end
	if has_conflict and not conflict_maps[buf] then
		conflict_maps[buf] = true
		for _, choice in ipairs({
			{ "<leader>co", "ours" },
			{ "<leader>ct", "theirs" },
			{ "<leader>ca", "all" },
			{ "dx", "none" },
		}) do
			vim.keymap.set("n", choice[1], function()
				choose_conflict(choice[2])
			end, { buffer = buf, desc = "Choose conflict " .. choice[2] })
		end
	elseif not has_conflict and conflict_maps[buf] then
		conflict_maps[buf] = nil
		for _, key in ipairs(conflict_keys) do
			pcall(vim.keymap.del, "n", key, { buffer = buf })
		end
	end
end

---Register Git review commands, mappings, and conflict actions.
function M.setup()
	local group = vim.api.nvim_create_augroup("NazoGitReview", { clear = true })
	vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost", "TextChanged", "TextChangedI" }, {
		group = group,
		callback = function(event)
			update_conflict_maps(event.buf)
		end,
	})
	vim.api.nvim_create_autocmd("BufWipeout", {
		group = group,
		callback = function(event)
			review_buffers[event.buf] = nil
			conflict_maps[event.buf] = nil
		end,
	})
	vim.keymap.set("n", "<leader>gd", M.open, { desc = "Review Git changes" })
	vim.keymap.set("n", "<leader>gh", M.file_history, { desc = "Git file history" })
	vim.keymap.set("n", "<leader>gH", M.branch_history, { desc = "Git branch history" })
	vim.keymap.set("n", "<leader>gc", M.close, { desc = "Close Git review" })
	vim.api.nvim_create_user_command("NazoGitReview", M.open, { desc = "Review tracked Git changes" })
	vim.api.nvim_create_user_command("NazoGitFileHistory", M.file_history, { desc = "Review current file history" })
	vim.api.nvim_create_user_command("NazoGitBranchHistory", M.branch_history, { desc = "Review branch history" })
	vim.api.nvim_create_user_command("NazoGitReviewClose", M.close, { desc = "Close Git review view" })
	vim.api.nvim_create_user_command("DiffviewOpen", M.open, { desc = "Review tracked Git changes" })
	vim.api.nvim_create_user_command("DiffviewFileHistory", function(command)
		if command.args == "" then
			M.branch_history()
		else
			history(vim.fn.fnamemodify(command.args, ":p"))
		end
	end, { nargs = "?", complete = "file", desc = "Review Git history" })
	vim.api.nvim_create_user_command("DiffviewClose", M.close, { desc = "Close Git review view" })
	vim.api.nvim_create_user_command("NazoConflictChoose", function(command)
		M.choose_conflict(command.args)
	end, {
		nargs = 1,
		complete = function()
			return { "ours", "theirs", "all", "none" }
		end,
		desc = "Choose a merge conflict side",
	})
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		update_conflict_maps(buf)
	end
end

return M
