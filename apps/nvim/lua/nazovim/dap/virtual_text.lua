local M = {}

local namespace = vim.api.nvim_create_namespace("NazoVimDapVirtualText")
local enabled = true
local dap, attached
local session_buffers = setmetatable({}, { __mode = "k" })
local stop_reasons = setmetatable({}, { __mode = "k" })

local function clear_session(session)
	local buf = session_buffers[session]
	if buf and vim.api.nvim_buf_is_valid(buf) then
		vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
	end
	session_buffers[session] = nil
	stop_reasons[session] = nil
end

local function source_buffer(frame)
	local path = frame.source and frame.source.path
	if path then
		local buf = vim.fn.bufnr(path)
		if buf >= 0 then
			return buf
		end
	end
	local buf = vim.api.nvim_get_current_buf()
	return vim.bo[buf].buftype == "" and buf or nil
end

local function variables_by_name(frame)
	local result = {}
	for _, scope in ipairs(frame.scopes or {}) do
		for _, variable in ipairs(scope.variables or {}) do
			if variable.name and result[variable.name] == nil then
				result[variable.name] = tostring(variable.value or "nil")
			end
		end
	end
	return result
end

local function local_scope(node)
	while node do
		local kind = node:type():lower()
		if kind:find("function", 1, true) or kind:find("method", 1, true) or kind:find("lambda", 1, true) then
			return node
		end
		node = node:parent()
	end
end

local function definitions(buf, stop_row)
	if vim.api.nvim_buf_line_count(buf) > 12000 then
		return {}
	end
	local node_ok, current = pcall(vim.treesitter.get_node, {
		bufnr = buf,
		pos = { math.max(0, stop_row), 0 },
	})
	if not node_ok or not current then
		return {}
	end
	local scope = local_scope(current)
	if not scope then
		return {}
	end
	local parser_ok, parser = pcall(vim.treesitter.get_parser, buf)
	if not parser_ok or not parser then
		return {}
	end
	local query_ok, query = pcall(vim.treesitter.query.get, parser:lang(), "locals")
	if not query_ok or not query then
		return {}
	end
	local start_row, _, end_row = scope:range()
	local found = {}
	local ok = pcall(function()
		for capture, item in query:iter_captures(scope, buf, start_row, end_row + 1) do
			local capture_name = query.captures[capture]
			if capture_name:match("definition%.var$") or capture_name:match("definition%.parameter$") then
				local name = vim.treesitter.get_node_text(item, buf)
				if type(name) == "string" and name ~= "" then
					local row, _, _, col = item:range()
					local candidate = { row = row, col = col, name = name }
					local previous = found[name]
					if not previous or (row <= stop_row and (previous.row > stop_row or row > previous.row)) then
						found[name] = candidate
					end
				end
			end
		end
	end)
	return ok and found or {}
end

local function comment_text(buf, text)
	local commentstring = vim.bo[buf].commentstring
	if commentstring and commentstring:find("%%s") then
		return commentstring:gsub("%%s", function()
			return text
		end, 1)
	end
	return text
end

local function concise(value)
	value = vim.trim(tostring(value or "nil")):gsub("%s+", " ")
	if vim.fn.strdisplaywidth(value) > 120 then
		value = vim.fn.strcharpart(value, 0, 119) .. "…"
	end
	return value
end

local function render(session)
	if not enabled or not session or not session.current_frame then
		return
	end
	local frame = session.current_frame
	local buf = source_buffer(frame)
	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	local previous = session_buffers[session]
	if previous and previous ~= buf and vim.api.nvim_buf_is_valid(previous) then
		vim.api.nvim_buf_clear_namespace(previous, namespace, 0, -1)
	end
	session_buffers[session] = buf
	vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
	local values = variables_by_name(frame)
	local stop_row = math.max(0, (frame.line or 1) - 1)
	for name, definition in pairs(definitions(buf, stop_row)) do
		local value = values[name]
		if value then
			local display = comment_text(buf, "DAP " .. name .. " = " .. concise(value))
			vim.api.nvim_buf_set_extmark(buf, namespace, definition.row, definition.col, {
				virt_text = { { "  " .. display, "NazoDapVirtualText" } },
				virt_text_pos = "inline",
				hl_mode = "combine",
				priority = 110,
			})
		end
	end
	local reason = stop_reasons[session]
	if reason and stop_row < vim.api.nvim_buf_line_count(buf) then
		vim.api.nvim_buf_set_extmark(buf, namespace, stop_row, 0, {
			virt_text = { { comment_text(buf, "Stopped: " .. concise(reason)), "NazoDapVirtualTextError" } },
			virt_text_pos = "eol",
			priority = 120,
		})
	end
end

local function schedule_render(session)
	vim.schedule(function()
		if enabled then
			render(session)
		end
	end)
end

---Attach custom extmark rendering to the built-in DAP client.
function M.attach(dap_instance)
	if attached or not enabled then
		return
	end
	dap = dap_instance
	attached = true
	local key = "nazovim_dap_virtual_text"
	dap.listeners.after.event_stopped[key] = function(session, body)
		stop_reasons[session] = body.reason == "exception" and (body.description or body.text or body.reason) or nil
		schedule_render(session)
	end
	dap.listeners.after.scopes[key] = function(session)
		schedule_render(session)
	end
	dap.listeners.after.variables[key] = function(session)
		schedule_render(session)
	end
	local function clear_listener(session)
		clear_session(session)
	end
	dap.listeners.after.event_terminated[key] = clear_listener
	dap.listeners.after.event_exited[key] = clear_listener
	dap.listeners.after.disconnect[key] = clear_listener
	local session = dap.session()
	if session then
		schedule_render(session)
	end
end

---Enable or disable DAP variable annotations and exception stop reasons.
function M.toggle()
	enabled = not enabled
	vim.g.nazovim_dap_virtual_text = enabled
	if not enabled then
		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
		end
	elseif dap then
		local session = dap.session()
		if session then
			schedule_render(session)
		end
	end
	vim.notify("DAP virtual text " .. (enabled and "enabled" or "disabled"), vim.log.levels.INFO, {
		title = "NazoVim",
	})
end

---Create highlights and a toggle command; the DAP plugin attaches later on demand.
function M.setup()
	enabled = vim.g.nazovim_dap_virtual_text ~= false
	vim.api.nvim_set_hl(0, "NazoDapVirtualText", { link = "Comment", default = true })
	vim.api.nvim_set_hl(0, "NazoDapVirtualTextError", { link = "DiagnosticVirtualTextError", default = true })
	vim.api.nvim_create_user_command("NazoDapVirtualTextToggle", M.toggle, {
		desc = "Toggle DAP variable virtual text",
	})
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = vim.api.nvim_create_augroup("NazoVimDapVirtualText", { clear = true }),
		callback = function()
			vim.api.nvim_set_hl(0, "NazoDapVirtualText", { link = "Comment", default = true })
			vim.api.nvim_set_hl(0, "NazoDapVirtualTextError", {
				link = "DiagnosticVirtualTextError",
				default = true,
			})
		end,
	})
end

return M
