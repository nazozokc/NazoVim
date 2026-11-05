local M = {}

local tasks = {}
local next_id = 1
local panel_buffer
local panel_window
local panel_group

local function task_lines()
	local ids = {}
	for id in pairs(tasks) do
		ids[#ids + 1] = id
	end
	table.sort(ids, function(a, b)
		return a > b
	end)
	local lines = { "Tasks  (Enter: output, r: run again, q: close)", "" }
	for _, id in ipairs(ids) do
		local task = tasks[id]
		local status = task.status
		if task.exit_code ~= nil then
			status = status .. " (" .. task.exit_code .. ")"
		end
		lines[#lines + 1] = string.format("[%d] %-12s %s", id, status, task.name)
	end
	if #ids == 0 then
		lines[#lines + 1] = "No tasks have been run. Use <leader>or to start one."
	end
	return lines, ids
end

local function refresh_panel()
	if not panel_buffer or not vim.api.nvim_buf_is_valid(panel_buffer) then
		return
	end
	local lines, ids = task_lines()
	vim.bo[panel_buffer].modifiable = true
	vim.api.nvim_buf_set_lines(panel_buffer, 0, -1, false, lines)
	vim.bo[panel_buffer].modifiable = false
	if #ids > 0 and panel_window and vim.api.nvim_win_is_valid(panel_window) then
		local selected = vim.api.nvim_win_get_cursor(panel_window)[1]
		vim.api.nvim_win_set_cursor(panel_window, { math.min(selected, #lines), 0 })
	end
end

local function selected_task()
	if not panel_buffer or not vim.api.nvim_buf_is_valid(panel_buffer) then
		return
	end
	local row = vim.api.nvim_win_get_cursor(panel_window)[1]
	local id = tonumber((vim.api.nvim_buf_get_lines(panel_buffer, row - 1, row, false)[1] or ""):match("^%[(%d+)%]"))
	return id and tasks[id]
end

local function open_output(task)
	if not task or not vim.api.nvim_buf_is_valid(task.bufnr) then
		return
	end
	vim.cmd("botright 14split")
	vim.api.nvim_win_set_buf(0, task.bufnr)
	vim.wo[0].number = false
	vim.wo[0].relativenumber = false
	vim.cmd("startinsert")
end

local function run_task(definition)
	if type(definition) ~= "table" or not definition.cmd then
		vim.notify("Task needs a command", vim.log.levels.ERROR, { title = "NazoVim Tasks" })
		return
	end
	local id = next_id
	next_id = next_id + 1
	local name = definition.name
		or (type(definition.cmd) == "string" and definition.cmd or table.concat(definition.cmd, " "))
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(buf, string.format("NazoTask://%d/%s", id, name:gsub("[^%w_.-]", "_")))
	vim.bo[buf].bufhidden = "hide"
	vim.bo[buf].swapfile = false
	local task = {
		id = id,
		name = name,
		cmd = definition.cmd,
		cwd = definition.cwd or vim.fn.getcwd(),
		env = definition.env,
		bufnr = buf,
		status = "running",
		started_at = os.time(),
	}
	tasks[id] = task
	local ok, job = pcall(vim.api.nvim_buf_call, buf, function()
		return vim.fn.termopen(task.cmd, {
			cwd = task.cwd,
			env = task.env,
			on_exit = function(_, code)
				vim.schedule(function()
					if tasks[id] then
						task.status = code == 0 and "success" or "failed"
						task.exit_code = code
						task.finished_at = os.time()
						refresh_panel()
					end
				end)
			end,
		})
	end)
	if ok and job > 0 then
		task.job = job
	end
	if not ok or job <= 0 then
		task.status = "failed"
		task.exit_code = job
		vim.notify("Could not start task: " .. tostring(job), vim.log.levels.ERROR, { title = "NazoVim Tasks" })
	end
	refresh_panel()
end

---Run a configured task or prompt for a shell command.
function M.run(command)
	if command and command ~= "" then
		run_task({ name = command, cmd = command })
		return
	end
	local configured = vim.g.nazovim_tasks
	if type(configured) == "table" and #configured > 0 then
		vim.ui.select(configured, {
			prompt = "Run task:",
			format_item = function(task)
				return type(task) == "table" and (task.name or tostring(task.cmd)) or tostring(task)
			end,
		}, function(task)
			if task then
				run_task(type(task) == "table" and task or { name = task, cmd = task })
			end
		end)
		return
	end
	vim.ui.input({ prompt = "Task command: " }, function(input)
		if input and vim.trim(input) ~= "" then
			run_task({ name = input, cmd = input })
		end
	end)
end

---Toggle the task history panel.
function M.toggle()
	if panel_window and vim.api.nvim_win_is_valid(panel_window) then
		vim.api.nvim_win_close(panel_window, true)
		panel_window = nil
		return
	end
	vim.cmd("botright 12split")
	panel_window = vim.api.nvim_get_current_win()
	panel_buffer = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_win_set_buf(panel_window, panel_buffer)
	vim.bo[panel_buffer].buftype = "nofile"
	vim.bo[panel_buffer].bufhidden = "wipe"
	vim.bo[panel_buffer].swapfile = false
	vim.bo[panel_buffer].filetype = "nazotasks"
	vim.wo[panel_window].number = false
	vim.wo[panel_window].relativenumber = false
	vim.wo[panel_window].signcolumn = "no"
	vim.wo[panel_window].cursorline = true
	vim.keymap.set("n", "q", M.toggle, { buffer = panel_buffer, desc = "Close task panel" })
	vim.keymap.set("n", "<CR>", function()
		open_output(selected_task())
	end, { buffer = panel_buffer, desc = "Open task output" })
	vim.keymap.set("n", "r", function()
		local task = selected_task()
		if task then
			run_task(task)
		end
	end, { buffer = panel_buffer, desc = "Run task again" })
	vim.keymap.set("n", "s", function()
		local task = selected_task()
		if task and task.status == "running" and task.job then
			task.status = "stopping"
			vim.fn.jobstop(task.job)
			refresh_panel()
		end
	end, { buffer = panel_buffer, desc = "Stop task" })
	panel_group = vim.api.nvim_create_augroup("NazoTasksPanel", { clear = true })
	vim.api.nvim_create_autocmd("WinClosed", {
		group = panel_group,
		callback = function(event)
			if tonumber(event.match) == panel_window then
				panel_window = nil
				panel_buffer = nil
				if panel_group then
					pcall(vim.api.nvim_del_augroup_by_id, panel_group)
					panel_group = nil
				end
			end
		end,
	})
	refresh_panel()
end

---Register task commands and keymaps.
function M.setup()
	vim.api.nvim_create_user_command("NazoTaskRun", function(options)
		M.run(options.args)
	end, { nargs = "?", desc = "Run a configured task or shell command" })
	vim.api.nvim_create_user_command("NazoTaskToggle", M.toggle, { desc = "Toggle task history" })
	vim.keymap.set("n", "<leader>or", M.run, { desc = "Run task" })
	vim.keymap.set("n", "<leader>ot", M.toggle, { desc = "Toggle task list" })
end

return M
