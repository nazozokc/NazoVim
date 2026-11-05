local M = {}

local title = "NazoVim Debugger"

---Events exposed to `dap_ui.lua` and `dap_virtual_text.lua` through
---`M.listeners`, mirroring the shape they were written against.
local events = {
	"connect",
	"disconnect",
	"event_breakpoint",
	"event_continued",
	"event_exited",
	"event_initialized",
	"event_output",
	"event_stopped",
	"event_terminated",
	"evaluate",
	"scopes",
	"stackTrace",
	"variables",
}

M.listeners = { before = {}, after = {} }
for _, event in ipairs(events) do
	M.listeners.before[event] = {}
	M.listeners.after[event] = {}
end

local function fire(phase, event, session, body, extra)
	local group = M.listeners[phase] and M.listeners[phase][event]
	if not group then
		return
	end
	for _, listener in pairs(group) do
		pcall(listener, session, body, extra)
	end
end

local function notify(message, level)
	vim.notify(message, level or vim.log.levels.INFO, { title = title })
end

---Encode a message with the DAP base protocol header.
---@param message table
---@return string
function M.encode(message)
	local body = vim.json.encode(message)
	return "Content-Length: " .. #body .. "\r\n\r\n" .. body
end

---Decode as many messages as `chunk` completes. `state` keeps the remainder.
---@param state { buffer?: string }
---@param chunk? string
---@return table[]
function M.parse(state, chunk)
	state.buffer = (state.buffer or "") .. (chunk or "")
	local messages = {}
	while true do
		local header_end = state.buffer:find("\r\n\r\n", 1, true)
		if not header_end then
			return messages
		end
		local header = state.buffer:sub(1, header_end - 1)
		local length = tonumber(header:match("[Cc]ontent%-[Ll]ength:%s*(%d+)"))
		if not length then
			-- Unparsable header: drop it and keep going.
			state.buffer = state.buffer:sub(header_end + 4)
		else
			local start = header_end + 4
			if #state.buffer < start + length - 1 then
				return messages
			end
			local body = state.buffer:sub(start, start + length - 1)
			state.buffer = state.buffer:sub(start + length)
			local ok, decoded = pcall(vim.json.decode, body)
			if ok and type(decoded) == "table" then
				messages[#messages + 1] = decoded
			end
		end
	end
end

---Adapters keyed by DAP type. `server` adapters print the port they listen on.
M.adapters = {
	["pwa-node"] = {
		transport = "server",
		cmd = { "js-debug", "0" },
		pattern = "Debug server listening at ([%w%.%-]+):(%d+)",
	},
	["pwa-chrome"] = {
		transport = "server",
		cmd = { "js-debug", "0" },
		pattern = "Debug server listening at ([%w%.%-]+):(%d+)",
	},
}

---Launch configurations per filetype.
M.configurations = {
	javascript = {
		{
			type = "pwa-node",
			request = "launch",
			name = "Launch file",
			program = "${file}",
			cwd = "${workspaceFolder}",
			console = "internalConsole",
			skipFiles = { "<node_internals>/**" },
		},
	},
	javascriptreact = nil,
	typescript = nil,
	typescriptreact = nil,
}
M.configurations.javascriptreact = M.configurations.javascript
M.configurations.typescript = M.configurations.javascript
M.configurations.typescriptreact = M.configurations.javascript

---Breakpoints per absolute path, shared by every session.
local breakpoints = {}

---Breakpoint helpers used by `dap_ui.lua`.
M.breakpoints = {
	---Return breakpoints grouped by buffer number.
	---@return table<integer, table[]>
	get = function()
		local grouped = {}
		for path, list in pairs(breakpoints) do
			local buf = vim.fn.bufnr(path)
			if buf >= 0 then
				grouped[buf] = list
			end
		end
		return grouped
	end,
	---Return the raw path keyed table.
	all = function()
		return breakpoints
	end,
}

---Return the session the UI should drive: the child the adapter asked for,
---otherwise the one `M.start` created.
---@return table?
function M.session()
	local child = M._child
	if child and not child.closed then
		return child
	end
	return M._session
end

local namespace = vim.api.nvim_create_namespace("NazoDapBreakpoints")

---Redraw the breakpoint signs of a buffer.
---@param buf? integer
function M.render_breakpoints(buf)
	buf = buf or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	local path = vim.api.nvim_buf_get_name(buf)
	vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
	local count = vim.api.nvim_buf_line_count(buf)
	for _, breakpoint in ipairs(breakpoints[path] or {}) do
		local row = breakpoint.line - 1
		if row >= 0 and row < count then
			vim.api.nvim_buf_set_extmark(buf, namespace, row, 0, {
				sign_text = breakpoint.condition and "◆" or "●",
				sign_hl_group = "NazoDapBreakpoint",
				priority = 120,
			})
		end
	end
end

local Session = {}
Session.__index = Session

---Write a message to the adapter.
---@param message table
function Session:write(message)
	self.transport.send(M.encode(message))
end

---Send a request and hand the response to `callback(err, body)`.
---@param command string
---@param arguments? table
---@param callback? fun(err: table?, body: table?)
---@return integer seq
function Session:request(command, arguments, callback)
	self.seq = self.seq + 1
	local seq = self.seq
	self.pending[seq] = { command = command, callback = callback }
	self:write({ seq = seq, type = "request", command = command, arguments = arguments })
	return seq
end

---Handle a message from the adapter.
---@param message table
function Session:handle(message)
	if message.type == "response" then
		local pending = self.pending[message.request_seq]
		if pending then
			self.pending[message.request_seq] = nil
		end
		local command = pending and pending.command or ""
		local err
		if message.success == false then
			err = message.body or { message = "request failed" }
		end
		fire("before", command, self, message.body, err)
		if pending and pending.callback then
			pending.callback(err, (not err) and message.body or nil)
		end
		fire("after", command, self, message.body, err)
	elseif message.type == "event" then
		self:event(message.event, message.body)
	elseif message.type == "request" then
		self:adapter_request(message)
	end
end

---Answer adapter-initiated requests.
---
---`startDebugging` asks the client to open a child session. js-debug always uses
---it for `pwa-node` launches: the adapter hands over a `configuration` that must
---be launched on a second connection to the same server. Everything else
---(`runInTerminal` in particular) is rejected because NazoVim only supports
---`internalConsole`.
---@param message table
function Session:adapter_request(message)
	local command = tostring(message.command)
	local supported = command == "startDebugging" and self.transport.connection ~= nil
	self.seq = self.seq + 1
	self:write({
		seq = self.seq,
		type = "response",
		request_seq = message.seq,
		command = command,
		success = supported,
		body = supported and {} or {
			error = {
				id = 1,
				format = "NazoVim does not support the " .. command .. " request",
			},
		},
	})
	if supported then
		local arguments = message.arguments or {}
		self:spawn_child(arguments.configuration, arguments.request)
	end
end

---Open the child session an adapter asked for.
---@param configuration table?
---@param request string?
---@return table?
function Session:spawn_child(configuration, request)
	if type(configuration) ~= "table" or self.transport.connection == nil then
		return nil
	end
	local child = M.open(self.transport.connection(), configuration, request or "launch")
	child.parent = self
	self.child = child
	M._child = child
	return child
end

---Dispatch an adapter event.
---@param name string
---@param body table?
function Session:event(name, body)
	fire("before", "event_" .. name, self, body)
	if name == "initialized" then
		self:on_initialized()
	elseif name == "stopped" then
		self:on_stopped(body or {})
	elseif name == "continued" or name == "terminated" or name == "exited" then
		self.current_frame = nil
		self.stopped_thread_id = nil
		self.stack = {}
		if name ~= "continued" then
			self.finished = true
			-- The adapter stays alive for the next launch; tear everything down.
			vim.schedule(function()
				M.close_all()
			end)
		end
	end
	fire("after", "event_" .. name, self, body)
end

---Send every breakpoint, then tell the adapter the configuration is done.
function Session:on_initialized()
	for path in pairs(breakpoints) do
		M.set_breakpoints(path, self)
	end
	self:request("setExceptionBreakpoints", { filters = {} })
	self:request("configurationDone", {})
end

---Remember the stopped thread and load its stack.
---@param body table
function Session:on_stopped(body)
	self.stopped_thread_id = body.threadId or 1
	self.current_frame = nil
	self.stack = {}
	self:request("stackTrace", {
		threadId = self.stopped_thread_id,
		startFrame = 0,
		levels = 40,
	}, function(err, response)
		if err or not response then
			return
		end
		self.stack = response.stackFrames or {}
		self.current_frame = self.stack[1]
		self:jump(self.current_frame)
		self:fetch_scopes()
	end)
end

---Fetch the scopes and variables of the current frame.
function Session:fetch_scopes()
	local frame = self.current_frame
	if not frame then
		return
	end
	self:request("scopes", { frameId = frame.id }, function(err, response)
		if err or not response then
			return
		end
		frame.scopes = response.scopes or {}
		fire("after", "scopes", self, response)
		for _, scope in ipairs(frame.scopes) do
			if (scope.variablesReference or 0) > 0 then
				self:request("variables", { variablesReference = scope.variablesReference }, function(verr, vres)
					if not verr and vres then
						scope.variables = vres.variables or {}
						fire("after", "variables", self, vres)
					end
				end)
			end
		end
	end)
end

---Move the cursor to a stack frame.
---@param frame table?
function Session.jump(_, frame)
	if not frame or vim.g.nazovim_dap_jump == false then
		return
	end
	local path = frame.source and frame.source.path
	if not path or path == "" then
		return
	end
	local ok, buf = pcall(vim.fn.bufadd, path)
	if not ok then
		return
	end
	pcall(vim.fn.bufload, buf)
	if vim.api.nvim_get_current_buf() ~= buf then
		pcall(vim.api.nvim_win_set_buf, 0, buf)
	end
	local line = math.max(1, frame.line or 1)
	local column = math.max(0, (frame.column or 1) - 1)
	pcall(vim.api.nvim_win_set_cursor, 0, { math.min(line, vim.api.nvim_buf_line_count(buf)), column })
end

---Close the adapter connection.
function Session:close()
	if self.closed then
		return
	end
	self.closed = true
	self.transport.close()
	if M._child == self then
		M._child = nil
	end
	if M._session == self then
		M._session = nil
	end
	if self.parent and not self.parent.closed then
		self.parent:close()
	end
	fire("after", "disconnect", self)
end

---Close every session and forget the adapter process.
function M.close_all()
	local child = M._child
	if child and not child.closed then
		child:close()
	end
	local session = M._session
	if session and not session.closed then
		session:close()
	end
	M._child = nil
	M._session = nil
end

---Build a stdio transport (used by tests and any stdio adapter).
---@param command string[]
---@param cwd? string
---@return table
function M.stdio_transport(command, cwd)
	local state = { buffer = "", handler = nil }
	local proc
	proc = vim.system(command, {
		cwd = cwd,
		text = true,
		stdin = true,
		stdout = function(_, data)
			if not data or data == "" then
				return
			end
			for _, message in ipairs(M.parse(state, data)) do
				if state.handler then
					state.handler(message)
				end
			end
		end,
		stderr = function(_, data)
			if data and data ~= "" then
				M._stderr = data
			end
		end,
	}, function()
		if M._session then
			vim.schedule(function()
				if M._session and M._session.transport.proc == proc then
					M._session:close()
				end
			end)
		end
	end)
	return {
		proc = proc,
		send = function(text)
			pcall(proc.write, proc, text)
		end,
		close = function()
			pcall(proc.kill, proc, "sigterm")
		end,
		set_handler = function(handler)
			state.handler = handler
		end,
	}
end

---Build a TCP transport for adapters that print the port they listen on.
---
---`connection()` opens an extra socket to the same adapter. js-debug asks the
---client for a child session through a reverse `startDebugging` request, and the
---child is a second DAP connection to the same server.
---@param adapter table
---@param cwd? string
---@return table
function M.server_transport(adapter, cwd)
	local state = { buffer = "", handler = nil }
	local outbox = {}
	local connected = false
	local closed = false
	local host, port
	local tcp = vim.uv.new_tcp()
	local proc

	local function flush()
		if not connected then
			return
		end
		while #outbox > 0 do
			tcp:write(table.remove(outbox, 1))
		end
	end

	local function connect(connect_host, connect_port)
		host, port = connect_host, tonumber(connect_port)
		tcp:connect(host, port, function(err)
			if err then
				notify("Cannot connect to " .. host .. ":" .. tostring(port), vim.log.levels.ERROR)
				return
			end
			connected = true
			tcp:read_start(function(read_err, data)
				if read_err or not data then
					return
				end
				for _, message in ipairs(M.parse(state, data)) do
					if state.handler then
						state.handler(message)
					end
				end
			end)
			flush()
		end)
	end

	proc = vim.system(adapter.cmd, {
		cwd = cwd,
		text = true,
		stdout = function(_, data)
			if not data or connected or closed then
				return
			end
			local found_host, found_port = data:match(adapter.pattern)
			if found_host then
				connect(found_host, found_port)
			end
		end,
		stderr = function() end,
	}, function()
		if not closed and M._session then
			vim.schedule(function()
				if M._session and M._session.transport.proc == proc then
					M._session:close()
				end
			end)
		end
	end)

	---Open an independent connection to the running adapter.
	---@return table
	local function connection()
		local child_state = { buffer = "", handler = nil }
		local child_outbox = {}
		local child_connected = false
		local child_closed = false
		local child_tcp = vim.uv.new_tcp()

		local function child_flush()
			if not child_connected then
				return
			end
			while #child_outbox > 0 do
				child_tcp:write(table.remove(child_outbox, 1))
			end
		end

		child_tcp:connect(host, port, function(err)
			if err then
				notify("Cannot connect to " .. tostring(host) .. ":" .. tostring(port), vim.log.levels.ERROR)
				return
			end
			child_connected = true
			child_tcp:read_start(function(read_err, data)
				if read_err or not data then
					return
				end
				for _, message in ipairs(M.parse(child_state, data)) do
					if child_state.handler then
						child_state.handler(message)
					end
				end
			end)
			child_flush()
		end)

		return {
			send = function(text)
				if child_closed then
					return
				end
				child_outbox[#child_outbox + 1] = text
				child_flush()
			end,
			close = function()
				child_closed = true
				pcall(child_tcp.close, child_tcp)
			end,
			set_handler = function(handler)
				child_state.handler = handler
			end,
		}
	end

	return {
		proc = proc,
		connection = connection,
		send = function(text)
			if closed then
				return
			end
			outbox[#outbox + 1] = text
			flush()
		end,
		close = function()
			closed = true
			pcall(tcp.close, tcp)
			pcall(proc.kill, proc, "sigterm")
		end,
		set_handler = function(handler)
			state.handler = handler
		end,
	}
end

---Expand `${file}` and `${workspaceFolder}` in a configuration.
---@param config table
---@return table
function M.resolve(config)
	local file = vim.api.nvim_buf_get_name(0)
	local root = vim.fn.getcwd()
	local resolved = vim.deepcopy(config)
	for key, value in pairs(resolved) do
		if type(value) == "string" then
			resolved[key] = (
				value:gsub("%${([%w_]+)}", function(name)
					if name == "file" then
						return file
					elseif name == "workspaceFolder" then
						return root
					end
					return "${" .. name .. "}"
				end)
			)
		end
	end
	return resolved
end

---Return the launch configuration for the current buffer.
---@return table?
function M.select_configuration()
	local configurations = M.configurations[vim.bo.filetype]
	if not configurations or #configurations == 0 then
		notify("No debug configuration for filetype '" .. vim.bo.filetype .. "'", vim.log.levels.WARN)
		return nil
	end
	return configurations[1]
end

local last_id = 0

---Create a session over `transport` and run the DAP handshake.
---@param transport table
---@param config table
---@param request? string
---@return table
function M.open(transport, config, request)
	last_id = last_id + 1
	local session = setmetatable({
		id = last_id,
		seq = 0,
		pending = {},
		config = config,
		transport = transport,
		stack = {},
	}, Session)
	transport.set_handler(function(message)
		vim.schedule(function()
			session:handle(message)
		end)
	end)
	fire("after", "connect", session)
	session:request("initialize", {
		clientID = "nazovim",
		clientName = "NazoVim",
		adapterID = config.type,
		locale = "en",
		linesStartAt1 = true,
		columnsStartAt1 = true,
		pathFormat = "path",
		supportsVariableType = true,
		supportsVariablePaging = false,
		supportsRunInTerminalRequest = false,
		supportsStartDebuggingRequest = true,
	}, function(err)
		if err then
			notify("initialize failed: " .. tostring(err.message), vim.log.levels.ERROR)
			session:close()
			return
		end
		session:request(request or config.request or "launch", config, function(lerr)
			if lerr then
				notify("launch failed: " .. tostring(lerr.message), vim.log.levels.ERROR)
				session:close()
			end
		end)
	end)
	return session
end

---Start a debug session.
---@param opts? { config?: table, cwd?: string }
---@return table? session
function M.start(opts)
	opts = opts or {}
	if M.session() then
		notify("A debug session is already running", vim.log.levels.WARN)
		return nil
	end
	local config = opts.config or M.select_configuration()
	if not config then
		return nil
	end
	local resolved = M.resolve(config)
	local adapter = opts.adapter or M.adapters[resolved.type]
	if not adapter then
		notify("No adapter for type '" .. tostring(resolved.type) .. "'", vim.log.levels.ERROR)
		return nil
	end
	if vim.fn.executable(adapter.cmd[1]) ~= 1 then
		notify(adapter.cmd[1] .. " is not executable (install vscode-js-debug)", vim.log.levels.ERROR)
		return nil
	end

	local cwd = opts.cwd or resolved.cwd or vim.fn.getcwd()
	local transport = adapter.transport == "server" and M.server_transport(adapter, cwd)
		or M.stdio_transport(adapter.cmd, cwd)
	local session = M.open(transport, resolved, resolved.request)
	M._session = session
	return session
end

---Send the breakpoints of one file to a session.
---@param path string
---@param session? table
function M.set_breakpoints(path, session)
	session = session or M.session()
	if not session then
		return
	end
	local payload = {}
	for _, breakpoint in ipairs(breakpoints[path] or {}) do
		payload[#payload + 1] = { line = breakpoint.line, condition = breakpoint.condition }
	end
	session:request("setBreakpoints", {
		source = { path = path, name = vim.fs.basename(path) },
		breakpoints = payload,
	})
end

---Toggle a breakpoint on the cursor line.
---@param condition? string
---@return boolean? added
function M.toggle_breakpoint(condition)
	local path = vim.api.nvim_buf_get_name(0)
	if path == "" then
		notify("The buffer has no file name", vim.log.levels.WARN)
		return nil
	end
	local line = vim.api.nvim_win_get_cursor(0)[1]
	local list = breakpoints[path]
	if not list then
		list = {}
		breakpoints[path] = list
	end
	local index
	for position, breakpoint in ipairs(list) do
		if breakpoint.line == line then
			index = position
			break
		end
	end
	local added
	if index then
		table.remove(list, index)
		added = false
	else
		list[#list + 1] = { line = line, condition = (condition and condition ~= "") and condition or nil }
		table.sort(list, function(left, right)
			return left.line < right.line
		end)
		added = true
	end
	M.render_breakpoints(0)
	M.set_breakpoints(path)
	return added
end

---Return the thread id to address.
---@return integer
local function thread_id()
	local session = M.session()
	return (session and session.stopped_thread_id) or 1
end

---Continue execution.
function M.continue()
	local session = M.session()
	if not session then
		notify("No debug session", vim.log.levels.WARN)
		return
	end
	session:request("continue", { threadId = thread_id() })
end

local function step(command)
	local session = M.session()
	if not session then
		notify("No debug session", vim.log.levels.WARN)
		return
	end
	session:request(command, { threadId = thread_id() })
end

function M.step_over()
	step("next")
end

function M.step_into()
	step("stepIn")
end

function M.step_out()
	step("stepOut")
end

---Select another frame of the current stack.
---@param delta integer
local function select_frame(delta)
	local session = M.session()
	if not session or not session.current_frame or #session.stack == 0 then
		return
	end
	local index = 1
	for position, frame in ipairs(session.stack) do
		if frame.id == session.current_frame.id then
			index = position
			break
		end
	end
	index = math.max(1, math.min(#session.stack, index + delta))
	session.current_frame = session.stack[index]
	session:jump(session.current_frame)
	session:fetch_scopes()
end

function M.up()
	select_frame(-1)
end

function M.down()
	select_frame(1)
end

---Evaluate an expression in the current frame.
---@param expression? string
function M.evaluate(expression)
	expression = expression or vim.fn.input("Evaluate: ")
	if expression == "" then
		return
	end
	local session = M.session()
	if not session or not session.current_frame then
		notify("No stopped frame to evaluate in", vim.log.levels.WARN)
		return
	end
	session:request("evaluate", {
		expression = expression,
		frameId = session.current_frame.id,
		context = "repl",
	}, function(err, response)
		if err then
			notify(tostring(err.message or "evaluate failed"), vim.log.levels.ERROR)
			return
		end
		notify(tostring(response and response.result or ""))
	end)
end

---End the session.
function M.terminate()
	local session = M.session()
	if not session then
		return
	end
	session:request("disconnect", { terminateDebuggee = true })
	M.close_all()
end

---Open a buffer listing every breakpoint.
function M.show_breakpoints()
	local paths = {}
	for path in pairs(breakpoints) do
		paths[#paths + 1] = path
	end
	table.sort(paths)
	local lines = { "NazoVim breakpoints", "" }
	local index = {}
	for _, path in ipairs(paths) do
		for _, breakpoint in ipairs(breakpoints[path]) do
			local suffix = breakpoint.condition and (" if " .. breakpoint.condition) or ""
			lines[#lines + 1] = vim.fn.fnamemodify(path, ":~:.") .. ":" .. breakpoint.line .. suffix
			index[#lines] = { path = path, line = breakpoint.line }
		end
	end
	if #lines == 2 then
		lines[#lines + 1] = "(none)"
	end
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = "nazodapbreakpoints"
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.cmd("botright 20split")
	local win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(win, buf)
	vim.keymap.set("n", "q", function()
		pcall(vim.api.nvim_win_close, win, true)
	end, { buffer = buf, desc = "Close the breakpoint list" })
	vim.keymap.set("n", "<CR>", function()
		local entry = index[vim.api.nvim_win_get_cursor(0)[1]]
		if not entry then
			return
		end
		pcall(vim.api.nvim_win_close, win, true)
		local target = vim.fn.bufadd(entry.path)
		vim.fn.bufload(target)
		vim.api.nvim_win_set_buf(0, target)
		pcall(vim.api.nvim_win_set_cursor, 0, { entry.line, 0 })
	end, { buffer = buf, desc = "Jump to the breakpoint" })
	vim.keymap.set("n", "d", function()
		local entry = index[vim.api.nvim_win_get_cursor(0)[1]]
		if not entry then
			return
		end
		local list = breakpoints[entry.path] or {}
		for position, breakpoint in ipairs(list) do
			if breakpoint.line == entry.line then
				table.remove(list, position)
				break
			end
		end
		if #list == 0 then
			breakpoints[entry.path] = nil
		end
		M.set_breakpoints(entry.path)
		pcall(vim.api.nvim_win_close, win, true)
		M.show_breakpoints()
	end, { buffer = buf, desc = "Delete the breakpoint" })
	return buf
end

---Report the adapter and session state.
function M.info()
	local lines = {}
	local available = {}
	for name, adapter in pairs(M.adapters) do
		if vim.fn.executable(adapter.cmd[1]) == 1 then
			available[#available + 1] = name
		end
	end
	table.sort(available)
	lines[#lines + 1] = "adapters: " .. (#available > 0 and table.concat(available, ", ") or "none")
	local total = 0
	for _, list in pairs(breakpoints) do
		total = total + #list
	end
	lines[#lines + 1] = "breakpoints: " .. total
	local session = M.session()
	if session then
		lines[#lines + 1] = "session: " .. tostring(session.config and session.config.name)
		lines[#lines + 1] = "state: " .. (session.current_frame and "stopped" or "running")
		if session.current_frame then
			lines[#lines + 1] = "frame: " .. tostring(session.current_frame.name)
		end
	else
		lines[#lines + 1] = "session: none"
	end
	notify(table.concat(lines, "\n"))
end

function M.setup()
	vim.api.nvim_set_hl(0, "NazoDapBreakpoint", { link = "DiagnosticError", default = true })
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = vim.api.nvim_create_augroup("NazoDapBreakpoints", { clear = true }),
		callback = function()
			vim.api.nvim_set_hl(0, "NazoDapBreakpoint", { link = "DiagnosticError", default = true })
		end,
	})
	vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
		group = vim.api.nvim_create_augroup("NazoDapBreakpointSigns", { clear = true }),
		callback = function(args)
			M.render_breakpoints(args.buf)
		end,
	})

	vim.api.nvim_create_user_command("NazoDapStart", function()
		M.start()
	end, { desc = "Start a debug session" })
	vim.api.nvim_create_user_command("NazoDapStop", M.terminate, { desc = "Stop the debug session" })
	vim.api.nvim_create_user_command("NazoDapContinue", M.continue, { desc = "Continue execution" })
	vim.api.nvim_create_user_command("NazoDapNext", M.step_over, { desc = "Step over" })
	vim.api.nvim_create_user_command("NazoDapStepIn", M.step_into, { desc = "Step into" })
	vim.api.nvim_create_user_command("NazoDapStepOut", M.step_out, { desc = "Step out" })
	vim.api.nvim_create_user_command("NazoDapBreakpoints", M.show_breakpoints, {
		desc = "List the breakpoints",
	})
	vim.api.nvim_create_user_command("NazoDapEval", function(command)
		M.evaluate(command.args ~= "" and command.args or nil)
	end, { nargs = "*", desc = "Evaluate an expression" })
	vim.api.nvim_create_user_command("NazoDapInfo", M.info, { desc = "Show the debugger state" })

	vim.keymap.set("n", "<F5>", M.continue, { desc = "DAP continue" })
	vim.keymap.set("n", "<F10>", M.step_over, { desc = "DAP step over" })
	vim.keymap.set("n", "<F11>", M.step_into, { desc = "DAP step into" })
	vim.keymap.set("n", "<F12>", M.step_out, { desc = "DAP step out" })
	vim.keymap.set("n", "<leader>db", function()
		M.toggle_breakpoint()
	end, { desc = "Toggle breakpoint" })
	vim.keymap.set("n", "<leader>B", function()
		M.toggle_breakpoint(vim.fn.input("Breakpoint condition: "))
	end, { desc = "Conditional breakpoint" })
	vim.keymap.set("n", "<leader>dB", M.show_breakpoints, { desc = "List breakpoints" })
	vim.keymap.set("n", "<leader>dl", function()
		M.start()
	end, { desc = "Start debug session" })
	vim.keymap.set("n", "<leader>de", function()
		M.evaluate()
	end, { desc = "Evaluate expression" })
	vim.keymap.set("n", "<leader>dq", M.terminate, { desc = "Stop debug session" })
	vim.keymap.set("n", "<leader>du", function()
		require("nazovim.dap.ui").toggle()
	end, { desc = "Toggle debugger panel" })

	local features = require("nazovim.features")
	if features.enabled("dap_ui") then
		require("nazovim.dap.ui").attach(M)
	end
	if features.enabled("dap_virtual_text") then
		require("nazovim.dap.virtual_text").attach(M)
	end
end

return M
