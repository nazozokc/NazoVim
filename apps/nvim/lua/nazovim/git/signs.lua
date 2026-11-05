local M = {}

local namespace = vim.api.nvim_create_namespace("NazoGitSigns")
local blame_namespace = vim.api.nvim_create_namespace("NazoGitBlame")
local generation = {}
local blame_enabled = false
local blame_generation = {}
local debounce = {}

local function git_root(buf)
	local path = vim.api.nvim_buf_get_name(buf)
	if path == "" or vim.fn.executable("git") ~= 1 then
		return nil
	end
	local result = vim.system({ "git", "-C", vim.fs.dirname(path), "rev-parse", "--show-toplevel" }, { text = true })
		:wait(1000)
	if not result or result.code ~= 0 then
		return nil
	end
	return vim.trim(result.stdout)
end

local function relative_path(root, buf)
	local path = vim.api.nvim_buf_get_name(buf)
	return vim.fs.relpath(root, path) or path
end

local function run_git(root, args, callback)
	local command = { "git", "-C", root }
	vim.list_extend(command, args)
	vim.system(command, { text = true }, callback)
end

local function parse_hunks(diff)
	local hunks, current = {}, nil
	for line in diff:gmatch("[^\n]+") do
		local old_start, old_count, new_start, new_count = line:match("^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@")
		if old_start then
			current = {
				old_start = tonumber(old_start),
				old_count = tonumber(old_count) or 1,
				new_start = tonumber(new_start),
				new_count = tonumber(new_count) or 1,
				lines = { line },
			}
			hunks[#hunks + 1] = current
		elseif current then
			current.lines[#current.lines + 1] = line
		end
	end
	return hunks
end

local function signs_for(hunks, line_count)
	local signs, totals = {}, { added = 0, changed = 0, deleted = 0 }
	for _, hunk in ipairs(hunks) do
		local row, additions, deletions = math.max(hunk.new_start - 1, 0), {}, 0
		local function flush_changes()
			local changed = math.min(#additions, deletions)
			for index, added_row in ipairs(additions) do
				if added_row < line_count then
					local kind = index <= changed and "change" or "add"
					signs[added_row] = kind
					totals[kind == "add" and "added" or "changed"] = totals[kind == "add" and "added" or "changed"] + 1
				end
			end
			local removed = deletions - changed
			if removed > 0 then
				local anchor = math.min(math.max(row - 1, 0), math.max(line_count - 1, 0))
				if line_count > 0 and not signs[anchor] then
					signs[anchor] = "delete"
				end
				totals.deleted = totals.deleted + removed
			end
			additions, deletions = {}, 0
		end
		for _, line in ipairs(hunk.lines) do
			if line:sub(1, 1) == "+" and line:sub(1, 3) ~= "+++" then
				additions[#additions + 1] = row
				row = row + 1
			elseif line:sub(1, 1) == "-" and line:sub(1, 3) ~= "---" then
				deletions = deletions + 1
			elseif line:sub(1, 1) == " " then
				flush_changes()
				row = row + 1
			end
		end
		flush_changes()
	end
	return signs, totals
end

local function update_status(buf, totals)
	local parts = {}
	if totals.added > 0 then
		parts[#parts + 1] = "+" .. totals.added
	end
	if totals.changed > 0 then
		parts[#parts + 1] = "~" .. totals.changed
	end
	if totals.deleted > 0 then
		parts[#parts + 1] = "-" .. totals.deleted
	end
	vim.b[buf].nazovim_git_status = table.concat(parts, " ")
	vim.cmd.redrawstatus()
end

local function render(buf, hunks)
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
	local signs, totals = signs_for(hunks, vim.api.nvim_buf_line_count(buf))
	local definitions = {
		add = { text = "▎", group = "NazoGitAdd" },
		change = { text = "▎", group = "NazoGitChange" },
		delete = { text = "▎", group = "NazoGitDelete" },
	}
	for row, kind in pairs(signs) do
		local sign = definitions[kind]
		vim.api.nvim_buf_set_extmark(buf, namespace, row, 0, {
			sign_text = sign.text,
			sign_hl_group = sign.group,
			priority = 10,
		})
	end
	update_status(buf, totals)
end

---Refresh Git diff signs and status for a buffer.
function M.refresh(buf)
	buf = buf or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= "" then
		return
	end
	local root = git_root(buf)
	if not root then
		vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
		vim.b[buf].nazovim_git_status = ""
		vim.cmd.redrawstatus()
		return
	end
	generation[buf] = (generation[buf] or 0) + 1
	local request = generation[buf]
	local path = relative_path(root, buf)
	run_git(root, { "diff", "--no-ext-diff", "--unified=0", "HEAD", "--", path }, function(result)
		vim.schedule(function()
			if not vim.api.nvim_buf_is_valid(buf) or generation[buf] ~= request then
				return
			end
			local hunks = result.code == 0 and parse_hunks(result.stdout) or {}
			render(buf, hunks)
			if blame_enabled and buf == vim.api.nvim_get_current_buf() then
				M.refresh_blame(buf)
			end
		end)
	end)
end

local function schedule_refresh(buf)
	if debounce[buf] then
		debounce[buf]:stop()
		debounce[buf]:close()
	end
	local timer = vim.uv.new_timer()
	debounce[buf] = timer
	timer:start(
		120,
		0,
		vim.schedule_wrap(function()
			debounce[buf] = nil
			-- A newer refresh may already have closed this timer.
			if timer:is_closing() then
				return
			end
			timer:stop()
			timer:close()
			M.refresh(buf)
		end)
	)
end

local function current_hunks(buf, callback)
	local root = git_root(buf)
	if not root then
		callback(nil, {})
		return
	end
	local path = relative_path(root, buf)
	run_git(root, { "diff", "--no-ext-diff", "--unified=3", "HEAD", "--", path }, function(result)
		vim.schedule(function()
			callback(root, result.code == 0 and parse_hunks(result.stdout) or {})
		end)
	end)
end

local function active_hunk(row, hunks)
	for index, hunk in ipairs(hunks) do
		local first = math.max(hunk.new_start, 1)
		local last = math.max(first, first + hunk.new_count - 1)
		if row >= first and row <= last then
			return index
		end
	end
	return nil
end

---Jump to the next or previous changed hunk.
function M.jump(direction)
	local buf = vim.api.nvim_get_current_buf()
	local win = vim.api.nvim_get_current_win()
	local row = vim.api.nvim_win_get_cursor(win)[1]
	current_hunks(buf, function(_, hunks)
		if not vim.api.nvim_win_is_valid(win) or vim.api.nvim_win_get_buf(win) ~= buf then
			return
		end
		if #hunks == 0 then
			vim.notify("No Git changes in this file", vim.log.levels.INFO, { title = "NazoVim" })
			return
		end
		local current = active_hunk(row, hunks)
		local target
		if direction > 0 then
			for index, hunk in ipairs(hunks) do
				if not current or index > current then
					target = hunk
					break
				end
			end
		else
			for index = #hunks, 1, -1 do
				if not current or index < current then
					target = hunks[index]
					break
				end
			end
		end
		if not target then
			vim.notify("No more Git changes in this direction", vim.log.levels.INFO, { title = "NazoVim" })
			return
		end
		local target_row = math.max(target.new_start - 1, 0)
		vim.api.nvim_win_set_cursor(0, { math.min(target_row + 1, vim.api.nvim_buf_line_count(buf)), 0 })
	end)
end

local function open_preview(hunk)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = "diff"
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, hunk.lines)
	local width = math.max(50, math.min(vim.o.columns - 6, 100))
	local height = math.max(3, math.min(#hunk.lines, vim.o.lines - 8))
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.max(1, math.floor((vim.o.lines - height) / 2) - 1),
		col = math.max(1, math.floor((vim.o.columns - width) / 2)),
		style = "minimal",
		border = "rounded",
		title = " Git hunk ",
		title_pos = "center",
	})
	vim.wo[win].wrap = false
	vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, silent = true })
	vim.keymap.set("n", "<Esc>", "<cmd>close<cr>", { buffer = buf, silent = true })
end

---Preview the changed hunk under the cursor.
function M.preview()
	local buf = vim.api.nvim_get_current_buf()
	local win = vim.api.nvim_get_current_win()
	local row = vim.api.nvim_win_get_cursor(win)[1]
	current_hunks(buf, function(_, hunks)
		if not vim.api.nvim_win_is_valid(win) or vim.api.nvim_win_get_buf(win) ~= buf then
			return
		end
		local index = active_hunk(row, hunks)
		if index then
			open_preview(hunks[index])
		else
			vim.notify("Cursor is not on a changed hunk", vim.log.levels.INFO, { title = "NazoVim" })
		end
	end)
end

---Refresh current-line blame virtual text.
function M.refresh_blame(buf)
	buf = buf or vim.api.nvim_get_current_buf()
	if not blame_enabled or not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	vim.api.nvim_buf_clear_namespace(buf, blame_namespace, 0, -1)
	local row = vim.api.nvim_win_get_cursor(0)[1]
	local root = git_root(buf)
	if not root then
		return
	end
	blame_generation[buf] = (blame_generation[buf] or 0) + 1
	local request = blame_generation[buf]
	local path = relative_path(root, buf)
	run_git(root, { "blame", "--line-porcelain", "-L", row .. "," .. row, "--", path }, function(result)
		vim.schedule(function()
			if not vim.api.nvim_buf_is_valid(buf) or blame_generation[buf] ~= request or not blame_enabled then
				return
			end
			local author = result.stdout:match("\nauthor ([^\n]+)")
			local date = result.stdout:match("\nauthor-time (%d+)")
			local summary = result.stdout:match("\nsummary ([^\n]+)")
			if not author then
				return
			end
			local when = date and os.date("%Y-%m-%d", tonumber(date)) or ""
			local text = string.format("%s · %s · %s", author, when, summary or "")
			vim.api.nvim_buf_set_extmark(buf, blame_namespace, row - 1, 0, {
				virt_text = { { text, "Comment" } },
				virt_text_pos = "eol",
				priority = 20,
			})
		end)
	end)
end

---Toggle current-line Git blame.
function M.toggle_blame()
	blame_enabled = not blame_enabled
	if blame_enabled then
		M.refresh_blame()
	else
		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			vim.api.nvim_buf_clear_namespace(buf, blame_namespace, 0, -1)
		end
	end
	vim.notify("Git blame " .. (blame_enabled and "enabled" or "disabled"), vim.log.levels.INFO, { title = "NazoVim" })
end

---Set up independent Git change signs and navigation.
function M.setup()
	local function set_highlights()
		vim.api.nvim_set_hl(0, "NazoGitAdd", { default = true, link = "DiffAdd" })
		vim.api.nvim_set_hl(0, "NazoGitChange", { default = true, link = "DiffChange" })
		vim.api.nvim_set_hl(0, "NazoGitDelete", { default = true, link = "DiffDelete" })
	end
	set_highlights()
	local group = vim.api.nvim_create_augroup("NazoGitSigns", { clear = true })
	vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = set_highlights })
	vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile", "BufWritePost", "FocusGained", "DirChanged" }, {
		group = group,
		callback = function(args)
			schedule_refresh(args.buf)
		end,
	})
	vim.api.nvim_create_autocmd("CursorHold", {
		group = group,
		callback = function(args)
			if blame_enabled then
				M.refresh_blame(args.buf)
			end
		end,
	})
	vim.api.nvim_create_autocmd("BufWipeout", {
		group = group,
		callback = function(args)
			generation[args.buf] = nil
			blame_generation[args.buf] = nil
			if debounce[args.buf] then
				debounce[args.buf]:stop()
				debounce[args.buf]:close()
				debounce[args.buf] = nil
			end
		end,
	})
	vim.keymap.set("n", "]h", function()
		M.jump(1)
	end, { desc = "Next Git hunk" })
	vim.keymap.set("n", "[h", function()
		M.jump(-1)
	end, { desc = "Previous Git hunk" })
	vim.keymap.set("n", "<leader>gp", M.preview, { desc = "Preview Git hunk" })
	vim.keymap.set("n", "<leader>gt", M.toggle_blame, { desc = "Toggle Git blame" })
	vim.api.nvim_create_user_command("NazoGitRefresh", function()
		M.refresh()
	end, { desc = "Refresh Git signs" })
end

return M
