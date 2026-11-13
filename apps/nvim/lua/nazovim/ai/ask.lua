local M = {}

local guard = require("nazovim.ai.lib.guard")

local title = "NazoAI"

---Providers understood by the built-in client, with their non-interactive form.
---Each CLI is asked once and prints the answer on stdout.
local providers = {
	claude = {
		binary = "claude",
		-- Feed the prompt through stdin so it never shows up in the process
		-- list. `--safe-mode` and `--restricted` keep project hooks, settings,
		-- CLAUDE.md, skills and MCP servers out of a one-shot answer.
		stdin = true,
		args = function()
			return { "-p", "--tools", "", "--restricted", "--strict-mcp-config", "--safe-mode" }
		end,
	},
	codex = {
		binary = "codex",
		stdin = true,
		args = function()
			-- `exec` is non-interactive. Read-only blocks writes and network;
			-- disabling the shell tools keeps the model from reading local
			-- files (or secrets) that were not attached to the prompt.
			return {
				"exec",
				"--skip-git-repo-check",
				"--sandbox",
				"read-only",
				"--color",
				"never",
				"--ephemeral",
				"--ignore-rules",
				"--ignore-user-config",
				"-c",
				"features.shell_tool=false",
				"-c",
				"features.unified_exec=false",
				"-",
			}
		end,
	},
	opencode = {
		binary = "opencode",
		args = function(prompt)
			-- `--pure` skips external plugins. The permission override in
			-- `env` denies every built-in tool that could read, write,
			-- execute or fetch, so this stays a question-answer call.
			return { "run", "--pure", prompt }
		end,
		env = {
			OPENCODE_PERMISSION = '{"bash":"deny","edit":"deny","glob":"deny","grep":"deny","list":"deny","lsp":"deny","question":"deny","read":"deny","skill":"deny","task":"deny","todowrite":"deny","webfetch":"deny","websearch":"deny","external_directory":"deny","doom_loop":"deny"}',
			OPENCODE_DISABLE_AUTOUPDATE = "1",
			OPENCODE_DISABLE_CLAUDE_CODE = "1",
			OPENCODE_DISABLE_PROJECT_CONFIG = "1",
		},
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
	size = 0,
	stop_requested = false,
	output_truncated = false,
	request = 0,
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
	local prompt = guard.prompt(question, contexts)
	return prompt
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
	local reason = guard.sensitive_path(context.path)
	if reason then
		return false, reason
	end
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
	local display = guard.display_path(context.path)
	local _, reason = attach(context)
	if reason then
		vim.notify("NazoAI skipped " .. display .. " (" .. reason .. ")", vim.log.levels.WARN, { title = title })
	else
		vim.notify("NazoAI added " .. display, vim.log.levels.INFO, { title = title })
	end
	return context
end

---Attach every loaded normal buffer to the next prompt.
---@return integer added
function M.add_buffers()
	local added, skipped = 0, 0
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == "" then
			local context = M.context(buf)
			local result, reason = attach(context)
			if reason then
				skipped = skipped + 1
			elseif result then
				added = added + 1
			end
		end
	end
	vim.notify(
		"NazoAI attached " .. added .. " buffers" .. (skipped > 0 and (" (skipped " .. skipped .. " sensitive)") or ""),
		vim.log.levels.INFO,
		{ title = title }
	)
	return added
end

---Attach the working tree diff (staged and unstaged) to the next prompt.
function M.add_diff()
	local ok, result = pcall(function()
		return vim.system(
			{ "git", "-C", vim.fn.getcwd(), "diff", "HEAD", "--no-color", "--no-ext-diff", "--no-textconv" },
			{ text = true }
		):wait(5000)
	end)
	if not ok or not result or result.code ~= 0 then
		local detail = ok and result and vim.trim(result.stderr or "") or "git is unavailable"
		notify_error(detail ~= "" and detail or "git diff failed")
		return
	end
	local body = vim.trim(result.stdout or "")
	if body == "" then
		vim.notify("NazoAI found no diff to attach", vim.log.levels.INFO, { title = title })
		return
	end
	attach({ path = "[git diff]", filetype = "diff", body = body })
	vim.notify("NazoAI attached the git diff", vim.log.levels.INFO, { title = title })
end

---Attach the current quickfix list to the next prompt.
function M.add_quickfix()
	local items = vim.fn.getqflist()
	if #items == 0 then
		vim.notify("NazoAI found an empty quickfix list", vim.log.levels.WARN, { title = title })
		return
	end
	local maximum = math.max(1, math.min(1000, tonumber(vim.g.nazovim_ai_quickfix_items) or 200))
	local lines = {}
	for index = 1, math.min(#items, maximum) do
		local item = items[index]
		local name = item.bufnr and item.bufnr > 0 and vim.fn.bufname(item.bufnr) or ""
		name = name ~= "" and vim.fn.fnamemodify(name, ":~:.") or "[No Name]"
		lines[#lines + 1] = string.format(
			"%s%s:%d:%d: %s",
			item.type and item.type ~= "" and ("[" .. item.type .. "] ") or "",
			name,
			item.lnum or 0,
			item.col or 0,
			item.text or ""
		)
	end
	if #items > maximum then
		lines[#lines + 1] = string.format("... %d more entries", #items - maximum)
	end
	attach({ path = "[quickfix]", filetype = "text", body = table.concat(lines, "\n") })
	vim.notify(
		"NazoAI attached " .. math.min(#items, maximum) .. " quickfix entries",
		vim.log.levels.INFO,
		{ title = title }
	)
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
	state.tail = vim.api.nvim_buf_line_count(buf)
	state.partial = ""
	state.answer = ""
	state.errors = ""
	state.size = 0
	state.output_truncated = false
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
	if #lines == 0 then
		return
	end
	local row = math.min(state.tail or vim.api.nvim_buf_line_count(buf), vim.api.nvim_buf_line_count(buf))
	vim.api.nvim_buf_set_lines(buf, row, row, false, lines)
	state.tail = row + #lines
	-- The panel window may be showing another buffer after `:enew`.
	if M.is_open() and vim.api.nvim_win_get_buf(state.win) == buf then
		local line = math.max(1, math.min(state.tail, vim.api.nvim_buf_line_count(buf)))
		vim.api.nvim_win_set_cursor(state.win, { line, 0 })
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
	state.stop_requested = true
	if not state.job then
		return false
	end
	pcall(state.job.kill, state.job, "sigterm")
	state.job = nil
	return true
end

---Stop a request that grew past the output budget.
local function stop_for_size()
	if not state.job then
		return
	end
	pcall(state.job.kill, state.job, "sigterm")
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
	state.stop_requested = false
	state.request = state.request + 1
	local request = state.request

	local contexts = {}
	vim.list_extend(contexts, state.files)
	if opts.context then
		contexts[#contexts + 1] = opts.context
	end
	local prompt, report = guard.prompt(question, contexts)
	if report.redactions > 0 then
		vim.notify(
			"NazoAI redacted " .. report.redactions .. " secret(s) before sending",
			vim.log.levels.WARN,
			{ title = title }
		)
	end
	if #report.skipped > 0 then
		local names = {}
		for _, skipped in ipairs(report.skipped) do
			names[#names + 1] = skipped.path .. " (" .. skipped.reason .. ")"
		end
		vim.notify("NazoAI skipped: " .. table.concat(names, ", "), vim.log.levels.WARN, { title = title })
	end
	if report.truncated then
		vim.notify("NazoAI truncated a large context", vim.log.levels.WARN, { title = title })
	end
	local command = M.command(provider, prompt)
	local shown = guard.redact(question)
	local output_limit = guard.limits().output
	start_block({ "## " .. shown, "", "> " .. provider, "" })

	-- Accumulate in the fast context so the exit handler sees the whole answer;
	-- only the buffer update has to be scheduled.
	local function collect(chunk, is_error)
		if state.request ~= request then
			return
		end
		if state.size >= output_limit then
			state.output_truncated = true
			stop_for_size()
			return
		end
		if state.size + #chunk > output_limit then
			chunk = chunk:sub(1, output_limit - state.size)
			state.output_truncated = true
		end
		state.size = state.size + #chunk
		if is_error then
			state.errors = state.errors .. chunk
		else
			state.answer = state.answer .. chunk
		end
		vim.schedule(function()
			stream(chunk)
		end)
		if state.output_truncated then
			stop_for_size()
		end
	end

	state.job = vim.system(command, {
		cwd = opts.cwd or vim.fn.getcwd(),
		text = true,
		env = providers[provider].env,
		stdin = providers[provider].stdin and prompt or nil,
		timeout = guard.timeout(),
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
			if state.request ~= request then
				return
			end
			state.job = nil
			if state.output_truncated then
				stream("\n\n_(output truncated by NazoAI)_")
			elseif state.stop_requested then
				stream("\n\n_(stopped)_")
			elseif result.code == 124 then
				stream("\n\n_(" .. provider .. " timed out)_")
			elseif result.code ~= 0 then
				stream("\n\n_(" .. provider .. " exited with " .. tostring(result.code) .. ")_")
			end
			stream("\n")
			local answer = state.answer
			state.history[#state.history + 1] = { question = shown, answer = answer, provider = provider }
			if opts.on_done and not state.stop_requested and not state.output_truncated then
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

---Ask before changing a buffer with model output.
---@return boolean
local function confirm_apply()
	if vim.g.nazovim_ai_apply_confirm == false then
		return true
	end
	return vim.fn.confirm("NazoAI: apply this code to the buffer?", "&Apply\n&Cancel", 2, "Question") == 1
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
	local tick = vim.api.nvim_buf_get_changedtick(buf)
	M.ask(question .. "\n\nReply with one fenced code block that replaces the target code. No prose.", {
		context = context,
		on_done = function(answer)
			if not vim.api.nvim_buf_is_valid(buf) then
				notify_error("The target buffer no longer exists")
				return
			end
			if vim.api.nvim_buf_get_changedtick(buf) ~= tick then
				notify_error("The target buffer changed while NazoAI was answering; nothing was applied")
				return
			end
			local blocks = M.code_blocks(answer)
			local code, reason = guard.code(blocks[1])
			if not code then
				if reason == "empty answer" then
					notify_error("The answer had no fenced code block")
				else
					notify_error("NazoAI will not apply the answer: " .. reason)
				end
				return
			end
			if not confirm_apply() then
				vim.notify("NazoAI kept the buffer unchanged", vim.log.levels.INFO, { title = title })
				return
			end
			if M.apply_code(buf, first, last, code) then
				vim.notify("NazoAI applied the answer", vim.log.levels.INFO, { title = title })
			end
		end,
	})
end

---Prompt templates for the current buffer or a visual range.
local templates = {
	explain = "Explain this code. Cover its purpose, control flow, inputs and outputs, and any surprising assumptions. Be concise.",
	fix = "Find bugs in this code and return only one fenced code block with the corrected version. No prose.",
	review = "Review this code for correctness, security and maintainability. List concrete issues with line references (injection, secret handling, error handling, unsafe I/O). Do not rewrite the whole file.",
	test = "Write focused tests for this code. Return one fenced code block with the tests and cover edge cases.",
	docs = "Write concise documentation comments for this code. Return one fenced code block with the documented version.",
}

---Ask a built-in template about the current buffer or a visual range.
---@param kind "explain"|"fix"|"review"|"test"|"docs"
---@param opts? { range?: boolean, first?: integer, last?: integer }
function M.template(kind, opts)
	opts = opts or {}
	local prompt = templates[kind]
	if not prompt then
		notify_error("Unknown NazoAI template: " .. tostring(kind))
		return
	end
	local buf = vim.api.nvim_get_current_buf()
	local first, last = 0, -1
	if opts.range then
		if opts.first then
			first, last = opts.first, opts.last or -1
		else
			first = vim.fn.line("'<") - 1
			last = vim.fn.line("'>")
		end
		if last <= first then
			first, last = 0, -1
		end
	end
	local context = M.context(buf, first, last)
	context.path = context.path .. " (target)"
	M.ask(prompt, { context = context })
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
	local function template_command(kind)
		return function(command)
			if command.range > 0 then
				M.template(kind, { range = true, first = command.line1 - 1, last = command.line2 })
			else
				M.template(kind)
			end
		end
	end

	vim.api.nvim_create_user_command("NazoAI", function(command)
		M.ask(command.args ~= "" and command.args or nil)
	end, { nargs = "*", desc = "Ask an AI CLI about the current context" })
	vim.api.nvim_create_user_command("NazoAIEdit", function()
		M.edit()
	end, { desc = "Ask an AI CLI and apply the returned code" })
	vim.api.nvim_create_user_command("NazoAIStop", M.stop, { desc = "Stop the running NazoAI request" })
	vim.api.nvim_create_user_command("NazoAIToggle", M.toggle, { desc = "Toggle the NazoAI panel" })
	vim.api.nvim_create_user_command("NazoAIDiff", M.add_diff, { desc = "Attach the git diff to NazoAI" })
	vim.api.nvim_create_user_command("NazoAIQuickfix", M.add_quickfix, { desc = "Attach the quickfix list to NazoAI" })
	for kind, description in pairs({
		explain = "Explain the current buffer or range",
		fix = "Ask for a corrected version of the buffer or range",
		review = "Review the buffer or range for correctness and security",
		test = "Ask for tests for the buffer or range",
		docs = "Ask for documentation for the buffer or range",
	}) do
		vim.api.nvim_create_user_command(
			"NazoAI" .. kind:sub(1, 1):upper() .. kind:sub(2),
			template_command(kind),
			{ range = true, desc = "NazoAI: " .. description }
		)
	end
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
	vim.keymap.set("n", "<leader>ad", M.add_diff, { desc = "AI attach git diff" })
	vim.keymap.set("n", "<leader>aq", M.add_quickfix, { desc = "AI attach quickfix" })
	for kind, key in pairs({ explain = "E", fix = "F", review = "R", test = "T", docs = "D" }) do
		vim.keymap.set({ "n", "x" }, "<leader>a" .. key, function()
			M.template(kind, { range = vim.fn.mode() ~= "n" })
		end, { desc = "AI " .. kind })
	end
end

return M
