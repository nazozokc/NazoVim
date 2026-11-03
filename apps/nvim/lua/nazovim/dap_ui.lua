local M = {}

local dap
local panel_buf
local panel_win
local stack = {}
local watches = {}
local pending_watches = {}
local watch_line_map = {}
local variable_line_map = {}
local stack_line_map = {}
local expanded_variables = {}

local function concise(value)
	return tostring(value or ""):gsub("\r", " "):gsub("\n", " ")
end

local function append_section(lines, title, entries)
	lines[#lines + 1] = ""
	lines[#lines + 1] = "  " .. title
	if #entries == 0 then
		lines[#lines + 1] = "    (none)"
		return
	end
	for _, entry in ipairs(entries) do
		lines[#lines + 1] = "    " .. entry
	end
end

local function append_variable(lines, variable, depth, variable_map)
	local reference = variable.variablesReference or 0
	local children = expanded_variables[reference]
	local marker = reference > 0 and (children and "▾ " or "▸ ") or "  "
	local value = variable.value
	if value == nil and reference > 0 then
		value = "{…}"
	end
	lines[#lines + 1] = string.rep("  ", depth) .. marker .. concise(variable.name) .. " = " .. concise(value)
	if reference > 0 then
		variable_map[#lines] = reference
	end
	if children and depth < 5 then
		for _, child in ipairs(children) do
			append_variable(lines, child, depth + 1, variable_map)
		end
	end
end

local function render()
	if not panel_buf or not vim.api.nvim_buf_is_valid(panel_buf) then
		return
	end
	local lines = { " NazoVim Debugger", "", "  q close · r refresh · a add watch · d remove watch" }
	local session = dap and dap.session()
	local frame = session and session.current_frame
	local scope_entries, breakpoint_entries, stack_entries = {}, {}, {}
	local scope_variable_map = {}
	watch_line_map = {}
	variable_line_map = {}
	stack_line_map = {}

	if frame then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "  Stopped: "
		lines[#lines + 1] = "    " .. concise(frame.name) .. "  " .. concise(frame.source and frame.source.path)
		lines[#lines + 1] = "    line " .. concise(frame.line)
		for _, scope in ipairs(frame.scopes or {}) do
			scope_entries[#scope_entries + 1] = "[" .. concise(scope.name) .. "]"
			for _, variable in ipairs(scope.variables or {}) do
				append_variable(scope_entries, variable, 1, scope_variable_map)
			end
		end
	end
	local scope_start_line = #lines + 3
	append_section(lines, "SCOPES", scope_entries)
	for entry_line, reference in pairs(scope_variable_map) do
		variable_line_map[scope_start_line + entry_line - 1] = reference
	end

	local ok, breakpoints = pcall(require, "dap.breakpoints")
	if ok then
		local grouped = breakpoints.get()
		local buffers = {}
		for buf in pairs(grouped) do
			buffers[#buffers + 1] = buf
		end
		table.sort(buffers, function(left, right)
			return vim.api.nvim_buf_get_name(left) < vim.api.nvim_buf_get_name(right)
		end)
		for _, buf in ipairs(buffers) do
			local path = vim.api.nvim_buf_get_name(buf)
			for _, breakpoint in ipairs(grouped[buf]) do
				local suffix = breakpoint.condition and (" if " .. breakpoint.condition) or ""
				breakpoint_entries[#breakpoint_entries + 1] = vim.fn.fnamemodify(path, ":~:.")
					.. ":"
					.. breakpoint.line
					.. suffix
			end
		end
	end
	append_section(lines, "BREAKPOINTS", breakpoint_entries)

	for index, item in ipairs(stack) do
		local marker = frame and item.id == frame.id and "▶ " or "  "
		stack_entries[#stack_entries + 1] = marker
			.. concise(item.name)
			.. "  "
			.. concise(item.source and item.source.path)
			.. ":"
			.. concise(item.line)
	end
	local stack_start_line = #lines + 3
	append_section(lines, "CALL STACK", stack_entries)
	for index = 1, #stack_entries do
		stack_line_map[stack_start_line + index - 1] = index
	end

	lines[#lines + 1] = ""
	lines[#lines + 1] = "  WATCHES"
	if #watches == 0 then
		lines[#lines + 1] = "    (none)"
	else
		for index, watch in ipairs(watches) do
			lines[#lines + 1] = "    " .. watch.expression .. " = " .. concise(watch.value or "…")
			watch_line_map[#lines] = index
		end
	end

	vim.bo[panel_buf].modifiable = true
	vim.api.nvim_buf_set_lines(panel_buf, 0, -1, false, lines)
	vim.bo[panel_buf].modifiable = false
end

local function refresh()
	if not dap then
		return
	end
	local session = dap.session()
	stack = {}
	if session and session.current_frame and session.stopped_thread_id then
		session:request("stackTrace", {
			threadId = session.stopped_thread_id,
			startFrame = 0,
			levels = 40,
		}, function(err, response)
			if err or not response then
				return
			end
			stack = response.stackFrames or {}
			vim.schedule(render)
		end)
	end
	render()
	if not session or not session.current_frame then
		return
	end
	for _, watch in ipairs(watches) do
		local key = tostring(session.id) .. ":" .. tostring(watch)
		if not pending_watches[key] then
			pending_watches[key] = true
			session:request("evaluate", {
				expression = watch.expression,
				frameId = session.current_frame.id,
				context = "watch",
			}, function(err, result)
				pending_watches[key] = nil
				watch.value = not err and result and result.result or (err and err.message or "unavailable")
				vim.schedule(render)
			end)
		end
	end
end

local function activate_cursor_item()
	local line = vim.api.nvim_win_get_cursor(0)[1]
	local reference = variable_line_map[line]
	if reference then
		if expanded_variables[reference] then
			expanded_variables[reference] = nil
			return render()
		end
		local session = dap and dap.session()
		if session then
			session:request("variables", { variablesReference = reference }, function(err, response)
				if not err and response then
					expanded_variables[reference] = response.variables or {}
					vim.schedule(render)
				end
			end)
		end
		return
	end
	local target = stack_line_map[line]
	local session = dap and dap.session()
	if target and session and session.current_frame then
		local current
		for index, frame in ipairs(stack) do
			if frame.id == session.current_frame.id then
				current = index
				break
			end
		end
		if current then
			local step = target > current and dap.up or dap.down
			for _ = 1, math.abs(target - current) do
				step()
			end
			vim.schedule(refresh)
		end
	end
end

function M.toggle()
	if not require("nazovim.features").enabled("dap_ui") then
		vim.notify("Debugger panel is disabled", vim.log.levels.INFO, { title = "NazoVim Debugger" })
		return
	end
	if panel_win and vim.api.nvim_win_is_valid(panel_win) then
		vim.api.nvim_win_close(panel_win, true)
		panel_win = nil
		return
	end
	if not dap then
		local ok, instance = pcall(require, "dap")
		if not ok then
			vim.notify("nvim-dap is not loaded", vim.log.levels.ERROR, { title = "NazoVim Debugger" })
			return
		end
		dap = instance
	end
	if not panel_buf or not vim.api.nvim_buf_is_valid(panel_buf) then
		panel_buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_name(panel_buf, "NazoDebugger://panel")
		vim.bo[panel_buf].buftype = "nofile"
		vim.bo[panel_buf].bufhidden = "hide"
		vim.bo[panel_buf].swapfile = false
		vim.bo[panel_buf].filetype = "nazovimdebug"
		vim.keymap.set("n", "q", M.toggle, { buffer = panel_buf, desc = "Close debugger panel" })
		vim.keymap.set("n", "r", refresh, { buffer = panel_buf, desc = "Refresh debugger panel" })
		vim.keymap.set(
			"n",
			"<CR>",
			activate_cursor_item,
			{ buffer = panel_buf, desc = "Expand value or select stack frame" }
		)
		vim.keymap.set("n", "a", function()
			vim.ui.input({ prompt = "Watch expression: " }, function(expression)
				if expression and expression ~= "" then
					watches[#watches + 1] = { expression = expression }
					refresh()
				end
			end)
		end, { buffer = panel_buf, desc = "Add watch expression" })
		vim.keymap.set("n", "d", function()
			local line = vim.api.nvim_win_get_cursor(0)[1]
			local index = watch_line_map[line]
			if index then
				table.remove(watches, index)
				refresh()
			end
		end, { buffer = panel_buf, desc = "Remove watch expression" })
	end
	vim.cmd("rightbelow vsplit")
	panel_win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(panel_win, panel_buf)
	vim.api.nvim_win_set_width(panel_win, 42)
	vim.wo[panel_win].winfixwidth = true
	refresh()
end

function M.attach(dap_instance)
	if not require("nazovim.features").enabled("dap_ui") then
		return
	end
	dap = dap_instance
	local key = "nazovim_dap_ui"
	local function update(callback)
		if panel_win and vim.api.nvim_win_is_valid(panel_win) then
			vim.schedule(callback)
		end
	end
	dap.listeners.after.event_stopped[key] = function()
		expanded_variables = {}
		update(refresh)
	end
	for _, event in ipairs({ "scopes", "variables" }) do
		dap.listeners.after[event][key] = function()
			update(render)
		end
	end
	for _, event in ipairs({ "event_continued", "event_terminated", "event_exited", "disconnect" }) do
		dap.listeners.after[event][key] = function()
			stack = {}
			update(render)
		end
	end
end

function M.setup()
	vim.api.nvim_create_user_command("NazoDapUi", M.toggle, { desc = "Toggle debugger information panel" })
end

return M
