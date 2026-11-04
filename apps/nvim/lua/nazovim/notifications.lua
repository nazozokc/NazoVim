local M = {}

local active = {}
local history = {}
local sequence = 0
local history_view_id = 0
local max_active = 5
local max_history = 200

local function wrap_line(line, width)
	local output, current, used = {}, "", 0
	for index = 0, vim.fn.strchars(line) - 1 do
		local character = vim.fn.strcharpart(line, index, 1)
		local size = vim.fn.strdisplaywidth(character)
		if used + size > width and current ~= "" then
			output[#output + 1] = current
			current, used = "", 0
		end
		current = current .. character
		used = used + size
	end
	output[#output + 1] = current
	return output
end

local function wrapped_lines(message, width)
	local output = {}
	for _, line in ipairs(vim.split(tostring(message), "\n", { plain = true })) do
		vim.list_extend(output, wrap_line(line, width))
	end
	return output
end

local function close(entry)
	if entry.timer then
		entry.timer:stop()
		entry.timer:close()
		entry.timer = nil
	end
	if entry.win and vim.api.nvim_win_is_valid(entry.win) then
		vim.api.nvim_win_close(entry.win, true)
	end
	for index, current in ipairs(active) do
		if current == entry then
			table.remove(active, index)
			break
		end
	end
	M.reflow()
end

function M.reflow()
	local row = 1
	for _, entry in ipairs(active) do
		if entry.win and vim.api.nvim_win_is_valid(entry.win) then
			local config = vim.api.nvim_win_get_config(entry.win)
			config.row = row
			config.col = math.max(0, vim.o.columns - config.width - 3)
			vim.api.nvim_win_set_config(entry.win, config)
			row = row + config.height + 2
		end
	end
end

local function display(entry)
	local max_width = math.max(1, math.min(68, vim.o.columns - 8))
	local title = entry.title
	local body_width = math.max(1, max_width - 4)
	local body = wrapped_lines(entry.message, body_width)
	local title_width = vim.fn.strdisplaywidth(title)
	local content_width = title_width
	for _, line in ipairs(body) do
		content_width = math.max(content_width, vim.fn.strdisplaywidth(line))
	end
	local width = math.min(max_width, math.max(content_width + 4, math.min(24, max_width)))
	local lines = { " " .. title }
	vim.list_extend(lines, body)
	local buf = vim.api.nvim_create_buf(false, true)
	entry.buf = buf
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	local height = math.max(1, math.min(#lines, vim.o.lines - 4))
	local stacked_height = 1
	for _, current in ipairs(active) do
		if current.win and vim.api.nvim_win_is_valid(current.win) then
			stacked_height = stacked_height + vim.api.nvim_win_get_config(current.win).height + 2
		end
	end
	local available_height = math.max(1, vim.o.lines - 3)
	while #active > 0 and stacked_height + height > available_height do
		local oldest = active[1]
		local config = oldest.win and vim.api.nvim_win_is_valid(oldest.win) and vim.api.nvim_win_get_config(oldest.win)
		stacked_height = stacked_height - (config and config.height + 2 or 0)
		close(oldest)
	end
	entry.win = vim.api.nvim_open_win(buf, false, {
		relative = "editor",
		style = "minimal",
		border = "rounded",
		row = 1,
		col = math.max(0, vim.o.columns - width - 3),
		width = width,
		height = height,
		focusable = false,
		zindex = 180,
		title = " " .. entry.level_name .. " ",
		title_pos = "right",
	})
	local border_group = entry.level >= vim.log.levels.ERROR and "NazoNotifyBorderError"
		or (entry.level >= vim.log.levels.WARN and "NazoNotifyBorderWarn" or "NazoNotifyBorder")
	vim.wo[entry.win].winhighlight = "Normal:NazoNotifyNormal,FloatBorder:" .. border_group
	vim.api.nvim_buf_add_highlight(buf, -1, "NazoNotifyTitle", 0, 0, -1)
	M.reflow()
end

function M.notify(message, level, opts)
	opts = opts or {}
	sequence = sequence + 1
	local severity = level or vim.log.levels.INFO
	local names = {
		[vim.log.levels.TRACE] = "TRACE",
		[vim.log.levels.DEBUG] = "DEBUG",
		[vim.log.levels.INFO] = "INFO",
		[vim.log.levels.WARN] = "WARN",
		[vim.log.levels.ERROR] = "ERROR",
	}
	local entry = {
		id = sequence,
		message = tostring(message),
		title = tostring(opts.title or "NazoVim"),
		level = severity,
		level_name = names[severity] or "INFO",
	}
	history[#history + 1] = entry
	if #history > max_history then
		table.remove(history, 1)
	end
	vim.schedule(function()
		if #active >= max_active then
			close(active[1])
		end
		active[#active + 1] = entry
		display(entry)
		local timeout = opts.timeout or (severity >= vim.log.levels.ERROR and 6500 or 4000)
		if timeout > 0 then
			entry.timer = vim.uv.new_timer()
			entry.timer:start(
				timeout,
				0,
				vim.schedule_wrap(function()
					close(entry)
				end)
			)
		end
	end)
	return entry.id
end

function M.history()
	local lines = {}
	for _, entry in ipairs(history) do
		local message_lines = vim.split(entry.message, "\n", { plain = true })
		lines[#lines + 1] = string.format("[%s] %s: %s", entry.level_name, entry.title, message_lines[1] or "")
		for index = 2, #message_lines do
			lines[#lines + 1] = "  " .. message_lines[index]
		end
	end
	local buf = vim.api.nvim_create_buf(false, true)
	history_view_id = history_view_id + 1
	vim.api.nvim_buf_set_name(buf, "NazoNotifications://history-" .. history_view_id)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, #lines > 0 and lines or { "No notifications yet" })
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].modifiable = false
	vim.cmd("botright split")
	vim.api.nvim_win_set_buf(0, buf)
end

function M.messages()
	local output = vim.fn.execute("messages")
	local lines = vim.split(output, "\n", { plain = true })
	local buf = vim.api.nvim_create_buf(false, true)
	history_view_id = history_view_id + 1
	vim.api.nvim_buf_set_name(buf, "NazoMessages://history-" .. history_view_id)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, #lines > 0 and lines or { "No messages" })
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].modifiable = false
	vim.cmd("botright split")
	vim.api.nvim_win_set_buf(0, buf)
end

function M.setup()
	for _, name in ipairs({ "NazoNotifyNormal", "NazoNotifyBorder", "NazoNotifyTitle" }) do
		vim.api.nvim_set_hl(0, name, { link = "NormalFloat", default = true })
	end
	vim.api.nvim_set_hl(0, "NazoNotifyBorderError", { link = "DiagnosticError", default = true })
	vim.api.nvim_set_hl(0, "NazoNotifyBorderWarn", { link = "DiagnosticWarn", default = true })
	vim.notify = M.notify
	vim.api.nvim_create_user_command("NazoNotifications", M.history, { desc = "Show notification history" })
	vim.api.nvim_create_user_command("NazoMessages", M.messages, { desc = "Show Neovim message history" })
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = vim.api.nvim_create_augroup("NazoNotifications", { clear = true }),
		callback = function()
			vim.api.nvim_set_hl(0, "NazoNotifyNormal", { link = "NormalFloat", default = true })
			vim.api.nvim_set_hl(0, "NazoNotifyBorder", { link = "FloatBorder", default = true })
			vim.api.nvim_set_hl(0, "NazoNotifyTitle", { link = "Title", default = true })
			vim.api.nvim_set_hl(0, "NazoNotifyBorderError", { link = "DiagnosticError", default = true })
			vim.api.nvim_set_hl(0, "NazoNotifyBorderWarn", { link = "DiagnosticWarn", default = true })
		end,
	})
	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = vim.api.nvim_create_augroup("NazoNotificationsCleanup", { clear = true }),
		callback = function()
			for _, entry in ipairs(active) do
				if entry.timer then
					entry.timer:stop()
					entry.timer:close()
				end
				if entry.win and vim.api.nvim_win_is_valid(entry.win) then
					vim.api.nvim_win_close(entry.win, true)
				end
			end
		end,
	})
end

return M
