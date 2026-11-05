local M = {}

local title = "NazoAI"

---Providers understood by the built-in client, with their non-interactive form.
---Each CLI is asked once and prints the answer on stdout.
local providers = {
	claude = {
		binary = "claude",
		args = function(prompt)
			return { "-p", prompt }
		end,
	},
	codex = {
		binary = "codex",
		args = function(prompt)
			return { "exec", "--skip-git-repo-check", "--color", "never", prompt }
		end,
	},
	opencode = {
		binary = "opencode",
		args = function(prompt)
			return { "run", prompt }
		end,
	},
}

---Preference order used when nothing is configured.
local order = { "claude", "codex", "opencode" }

local state = {
	buf = nil,
	win = nil,
	job = nil,
	provider = nil,
	files = {},
	history = {},
	partial = "",
	tail = nil,
	answer = "",
	errors = "",
}

local function notify_error(message)
	vim.notify(message, vim.log.levels.ERROR, { title = title })
end

---Return the providers whose CLI is on PATH, in preference order.
---@return string[]
function M.available()
	local result = {}
	for _, name in ipairs(order) do
		if vim.fn.executable(providers[name].binary) == 1 then
			result[#result + 1] = name
		end
	end
	return result
end

---Return the provider to use: the selection, the configuration, or the first
---available CLI.
---@return string?
function M.provider()
	if state.provider then
		return state.provider
	end
	local configured = vim.g.nazovim_ai_provider
	if type(configured) ~= "string" or configured == "" then
		configured = vim.env.NAZOVIM_AI_PROVIDER
	end
	if type(configured) == "string" and providers[configured] then
		return configured
	end
	return M.available()[1]
end

---Pick the provider with `vim.ui.select`.
function M.select_provider()
	local available = M.available()
	if #available == 0 then
		notify_error("No AI CLI found. Install claude, codex or opencode.")
		return
	end
	local current = M.provider()
	vim.ui.select(available, {
		prompt = "NazoAI provider",
		format_item = function(item)
			return item == current and (item .. " (current)") or item
		end,
	}, function(choice)
		if choice then
			state.provider = choice
			vim.notify("NazoAI provider: " .. choice, vim.log.levels.INFO, { title = title })
		end
	end)
end

---Build the argv for a provider.
---@param provider string
---@param prompt string
---@return string[]?
function M.command(provider, prompt)
	local definition = providers[provider]
	if not definition then
		return nil
	end
	local command = { definition.binary }
	vim.list_extend(command, definition.args(prompt))
	return command
end

---Capture a buffer range as a prompt context block.
---@param buf? integer
---@param first? integer
---@param last? integer
---@return { path: string, filetype: string, body: string }
function M.context(buf, first, last)
	buf = buf or vim.api.nvim_get_current_buf()
	local name = vim.api.nvim_buf_get_name(buf)
	local path = name ~= "" and vim.fn.fnamemodify(name, ":~:.") or "[No Name]"
	return {
		path = path,
		filetype = vim.bo[buf].filetype,
		body = table.concat(vim.api.nvim_buf_get_lines(buf, first or 0, last or -1, false), "\n"),
	}
end

---Join the question and the contexts into a single prompt.
---@param question string
---@param contexts? { path: string, filetype: string, body: string }[]
---@return string
function M.build_prompt(question, contexts)
	local parts = { question }
	for _, context in ipairs(contexts or {}) do
		parts[#parts + 1] = table.concat({
			"### " .. context.path,
			"```" .. (context.filetype or ""),
			context.body,
			"```",
		}, "\n")
	end
	return table.concat(parts, "\n\n")
end

---Return the fenced code blocks of an answer, in order.
---@param text string
---@return string[]
function M.code_blocks(text)
	local blocks = {}
	for body in text:gmatch("```[%w_%+%-%.]*\n(.-)```") do
		blocks[#blocks + 1] = (body:gsub("\n$", ""))
	end
	return blocks
end

---Return the files attached to the next prompt.
---@return string[]
function M.files()
	local result = {}
	for _, context in ipairs(state.files) do
		result[#result + 1] = context.path
	end
	return result
end

local function attach(context)
	for _, existing in ipairs(state.files) do
		if existing.path == context.path then
			existing.body = context.body
			existing.filetype = context.filetype
			return false
		end
	end
	state.files[#state.files + 1] = context
	return true
end

---Attach the current buffer to the next prompt.
function M.add_current()
	local context = M.context()
	attach(context)
	vim.notify("NazoAI added " .. context.path, vim.log.levels.INFO, { title = title })
	return context
end

---Attach every loaded normal buffer to the next prompt.
---@return integer added
function M.add_buffers()
	local added = 0
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == "" then
			if attach(M.context(buf)) then
				added = added + 1
			end
		end
	end
	vim.notify("NazoAI attached " .. added .. " buffers", vim.log.levels.INFO, { title = title })
	return added
end

---Drop every attached file.
function M.clear_files()
	state.files = {}
end

---Return the panel buffer, when it exists.
---@return integer?
function M.buffer()
	if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
		return state.buf
	end
	return nil
end

---Return whether the panel window is visible.
function M.is_open()
	return state.win ~= nil and vim.api.nvim_win_is_valid(state.win)
end

local function panel_width()
	return math.max(20, tonumber(vim.g.nazovim_ai_width) or 80)
end

local function ensure_panel()
	if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
		if not M.is_open() then
			vim.cmd("botright " .. panel_width() .. "vsplit")
			state.win = vim.api.nvim_get_current_win()
			vim.api.nvim_win_set_buf(state.win, state.buf)
		end
		return state.buf, state.win
	end
	state.buf = vim.api.nvim_create_buf(false, true)
	vim.bo[state.buf].bufhidden = "hide"
	vim.bo[state.buf].swapfile = false
	vim.bo[state.buf].filetype = "markdown"
	vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, { "# NazoAI", "" })
	vim.cmd("botright " .. panel_width() .. "vsplit")
	state.win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(state.win, state.buf)
	return state.buf, state.win
end

---Append a new block and remember the line that streaming extends.
---@param header string[]
---@return integer buf
local function start_block(header)
	local buf = ensure_panel()
	vim.bo[buf].modifiable = true
	local count = vim.api.nvim_buf_line_count(buf)
	local lines = { "" }
	for _, entry in ipairs(header) do
		vim.list_extend(lines, vim.split(entry, "\n", { plain = true }))
	end
	lines[#lines + 1] = ""
	vim.api.nvim_buf_set_lines(buf, count, count, false, lines)
	state.tail = count + #lines - 1
	state.partial = ""
	state.answer = ""
	state.errors = ""
	return buf
end

---Append a chunk to the panel, keeping the unterminated tail line in place.
---@param text string
local function stream(text)
	local buf = state.buf
	if not (buf and vim.api.nvim_buf_is_valid(buf)) then
		return
	end
	local combined = state.partial .. text
	local lines = vim.split(combined, "\n", { plain = true })
	state.partial = table.remove(lines) or ""
	local row = state.tail or (vim.api.nvim_buf_line_count(buf) - 1)
	vim.api.nvim_buf_set_lines(buf, row, row + 1, false, lines)
	state.tail = row + #lines - 1
	-- The panel window may be showing another buffer after `:enew`.
	if M.is_open() and vim.api.nvim_win_get_buf(state.win) == buf then
		vim.api.nvim_win_set_cursor(state.win, { state.tail + 1, 0 })
	end
end

---Show the panel, or focus it when it is already visible.
function M.focus()
	local _, win = ensure_panel()
	vim.api.nvim_set_current_win(win)
end

---Show or hide the panel without losing the conversation.
function M.toggle()
	if M.is_open() then
		pcall(vim.api.nvim_win_close, state.win, false)
		state.win = nil
	else
		ensure_panel()
	end
end

---Stop the running request.
---@return boolean stopped
function M.stop()
	if not state.job then
		return false
	end
	pcall(state.job.kill, state.job, "sigterm")
	state.job = nil
	return true
end

---Ask the configured CLI and stream the answer into the panel.
---@param question? string
---@param opts? { context?: table, cwd?: string, on_done?: fun(answer: string) }
---@return table? job
function M.ask(question, opts)
	opts = opts or {}
	question = question or vim.fn.input("NazoAI: ")
	if question == "" then
		return nil
	end
	local provider = M.provider()
	if not provider then
		notify_error("No AI CLI found. Install claude, codex or opencode.")
		return nil
	end
	local binary = providers[provider].binary
	if vim.fn.executable(binary) ~= 1 then
		notify_error(binary .. " is not executable")
		return nil
	end
	M.stop()

	local contexts = {}
	vim.list_extend(contexts, state.files)
	if opts.context then
		contexts[#contexts + 1] = opts.context
	end
	local command = M.command(provider, M.build_prompt(question, contexts))
	start_block({ "## " .. question, "", "> " .. provider, "" })

	-- Accumulate in the fast context so the exit handler sees the whole answer;
	-- only the buffer update has to be scheduled.
	local function collect(chunk, is_error)
		if is_error then
			state.errors = state.errors .. chunk
		else
			state.answer = state.answer .. chunk
		end
		vim.schedule(function()
			stream(chunk)
		end)
	end

	state.job = vim.system(command, {
		cwd = opts.cwd or vim.fn.getcwd(),
		text = true,
		stdout = function(_, data)
			if data and data ~= "" then
				collect(data, false)
			end
		end,
		stderr = function(_, data)
			if data and data ~= "" then
				collect(data, true)
			end
		end,
	}, function(result)
		vim.schedule(function()
			state.job = nil
			if result.code ~= 0 then
				stream("\n\n_(" .. provider .. " exited with " .. tostring(result.code) .. ")_")
			end
			stream("\n")
			local answer = state.answer
			state.history[#state.history + 1] = { question = question, answer = answer, provider = provider }
			if opts.on_done then
				opts.on_done(answer)
			end
		end)
	end)
	return state.job
end

---Replace a buffer range with a code block.
---@param buf integer
---@param first integer
---@param last integer
---@param code string
---@return boolean applied
function M.apply_code(buf, first, last, code)
	if not vim.api.nvim_buf_is_valid(buf) then
		return false
	end
	local count = vim.api.nvim_buf_line_count(buf)
	local stop = last < 0 and count or math.min(last, count)
	vim.api.nvim_buf_set_lines(buf, first, stop, false, vim.split(code, "\n", { plain = true }))
	return true
end

---Ask the CLI to rewrite the buffer (or the last visual range) and apply the
---first fenced block of the answer.
---@param opts? { range?: boolean }
function M.edit(opts)
	opts = opts or {}
	local buf = vim.api.nvim_get_current_buf()
	local first, last = 0, -1
	if opts.range then
		first = vim.fn.line("'<") - 1
		last = vim.fn.line("'>")
		if last <= first then
			first, last = 0, -1
		end
	end
	local question = vim.fn.input("NazoAI edit: ")
	if question == "" then
		return
	end
	local context = M.context(buf, first, last)
	context.path = context.path .. " (target)"
	M.ask(question .. "\n\nReply with one fenced code block that replaces the target code. No prose.", {
		context = context,
		on_done = function(answer)
			local blocks = M.code_blocks(answer)
			local code = blocks[1]
			if not code then
				notify_error("The answer had no fenced code block")
				return
			end
			if M.apply_code(buf, first, last, code) then
				vim.notify("NazoAI applied the answer", vim.log.levels.INFO, { title = title })
			end
		end,
	})
end

---Replay a previous exchange in the panel.
function M.history()
	if #state.history == 0 then
		vim.notify("No NazoAI history yet", vim.log.levels.INFO, { title = title })
		return
	end
	local items = {}
	for index = #state.history, 1, -1 do
		items[#items + 1] = state.history[index]
	end
	vim.ui.select(items, {
		prompt = "NazoAI history",
		format_item = function(item)
			return (item.question:gsub("\n.*", ""))
		end,
	}, function(item)
		if not item then
			return
		end
		start_block({ "## " .. item.question, "", "> " .. item.provider .. " (history)", "" })
		stream(item.answer)
		stream("\n")
	end)
end

function M.setup()
	vim.api.nvim_create_user_command("NazoAI", function(command)
		M.ask(command.args ~= "" and command.args or nil)
	end, { nargs = "*", desc = "Ask an AI CLI about the current context" })
	vim.api.nvim_create_user_command("NazoAIEdit", function()
		M.edit()
	end, { desc = "Ask an AI CLI and apply the returned code" })
	vim.api.nvim_create_user_command("NazoAIStop", M.stop, { desc = "Stop the running NazoAI request" })
	vim.api.nvim_create_user_command("NazoAIToggle", M.toggle, { desc = "Toggle the NazoAI panel" })
	vim.api.nvim_create_user_command("NazoAIFiles", function()
		local files = M.files()
		vim.notify(
			#files > 0 and table.concat(files, "\n") or "No files attached",
			vim.log.levels.INFO,
			{ title = title }
		)
	end, { desc = "List the files attached to NazoAI" })

	vim.keymap.set("n", "<leader>aa", function()
		M.ask()
	end, { desc = "AI ask" })
	vim.keymap.set("n", "<leader>an", function()
		M.clear_files()
		M.ask()
	end, { desc = "AI new ask" })
	vim.keymap.set({ "n", "x" }, "<leader>ae", function()
		M.edit({ range = vim.fn.mode() ~= "n" })
	end, { desc = "AI edit" })
	vim.keymap.set("n", "<leader>at", M.toggle, { desc = "AI toggle panel" })
	vim.keymap.set("n", "<leader>af", M.focus, { desc = "AI focus panel" })
	vim.keymap.set("n", "<leader>aS", M.stop, { desc = "AI stop" })
	vim.keymap.set("n", "<leader>ac", M.add_current, { desc = "AI add current file" })
	vim.keymap.set("n", "<leader>aB", M.add_buffers, { desc = "AI add all buffers" })
	vim.keymap.set("n", "<leader>aC", M.clear_files, { desc = "AI clear files" })
	vim.keymap.set("n", "<leader>a?", M.select_provider, { desc = "AI select provider" })
	vim.keymap.set("n", "<leader>ah", M.history, { desc = "AI history" })
end

return M
