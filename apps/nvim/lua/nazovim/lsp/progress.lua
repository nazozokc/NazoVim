local M = {}
local tasks = {}
local buf, win
local generation = 0

local function close()
	if win and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_win_close(win, true)
	end
	win = nil
end

local function draw()
	local lines = {}
	if not vim.api.nvim_get_mode().mode:match("^[iR]") then
		for _, client_tasks in pairs(tasks) do
			for _, task in pairs(client_tasks) do
				lines[#lines + 1] = string.format(
					"%s %s: %s%s%s",
					task.done and "✔" or "…",
					task.client,
					task.title or "",
					task.message and " — " .. task.message or "",
					task.percentage and " " .. task.percentage .. "%" or ""
				)
			end
		end
	end
	if #lines == 0 or vim.o.lines < 5 then
		close()
		return
	end
	table.sort(lines)
	local height = math.min(#lines, 5, vim.o.lines - 4)
	lines = vim.list_slice(lines, 1, height)
	local width = 1
	for _, line in ipairs(lines) do
		width = math.max(width, vim.fn.strdisplaywidth(line))
	end
	width = math.min(width, math.max(1, vim.o.columns - 4))
	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		buf = vim.api.nvim_create_buf(false, true)
	end
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	local config = {
		relative = "editor",
		row = math.max(0, vim.o.lines - vim.o.cmdheight - height - 2),
		col = math.max(0, vim.o.columns - width - 2),
		width = width,
		height = height,
		style = "minimal",
		focusable = false,
		zindex = 45,
	}
	if win and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_win_set_config(win, config)
	else
		win = vim.api.nvim_open_win(buf, false, config)
		vim.wo[win].winhighlight = "Normal:NormalFloat"
		vim.wo[win].winblend = 5
	end
end

---Consume one LspProgress event, preserving separate client/token lifetimes.
function M.handle(data)
	local params = data and data.params
	local value = params and params.value
	if type(value) ~= "table" or not value.kind then
		return
	end
	local id, token = data.client_id, params.token
	if not id or token == nil then
		return
	end
	local client = vim.lsp.get_client_by_id(id)
	tasks[id] = tasks[id] or {}
	local task = value.kind ~= "begin" and tasks[id][token] or nil
	task = task or { client = client and client.name or tostring(id) }
	for _, key in ipairs({ "title", "message", "percentage" }) do
		if value[key] ~= nil then
			task[key] = type(value[key]) == "string" and value[key]:gsub("[\r\n]", " ") or value[key]
		end
	end
	task.done = value.kind == "end"
	tasks[id][token] = task
	if task.done then
		local current = generation
		vim.defer_fn(function()
			if generation == current and tasks[id] and tasks[id][token] == task and task.done then
				tasks[id][token] = nil
				if not next(tasks[id]) then
					tasks[id] = nil
				end
				draw()
			end
		end, 2000)
	end
	draw()
end

---Listen for progress without overriding LSP handlers or vim.notify.
function M.setup()
	generation = generation + 1
	tasks = {}
	close()
	local group = vim.api.nvim_create_augroup("NazoProgress", { clear = true })
	vim.api.nvim_create_autocmd("LspProgress", {
		group = group,
		callback = function(args)
			M.handle(args.data)
		end,
	})
	vim.api.nvim_create_autocmd({ "InsertEnter", "InsertLeave", "VimResized" }, { group = group, callback = draw })
	vim.api.nvim_create_autocmd("LspDetach", {
		group = group,
		callback = function(args)
			local id = args.data.client_id
			vim.schedule(function()
				local client = vim.lsp.get_client_by_id(id)
				if not client or client:is_stopped() or not next(client.attached_buffers) then
					tasks[id] = nil
					draw()
				end
			end)
		end,
	})
	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = group,
		callback = function()
			generation = generation + 1
			tasks = {}
			close()
		end,
	})
end

return M
