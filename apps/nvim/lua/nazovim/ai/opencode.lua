local M = {}

local guard = require("nazovim.ai.lib.guard")

local title = "opencode"
local state = { buf = nil, win = nil }

local function notify_error(message)
	vim.notify(message, vim.log.levels.ERROR, { title = title })
end

local function geometry()
	local width = math.max(1, math.floor(vim.o.columns * 0.8))
	local height = math.max(1, math.floor((vim.o.lines - vim.o.cmdheight) * 0.8))
	return {
		relative = "editor",
		style = "minimal",
		border = "rounded",
		width = width,
		height = height,
		row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
		col = math.max(0, math.floor((vim.o.columns - width) / 2)),
	}
end

---Return whether the opencode window is visible.
function M.is_open()
	return state.win ~= nil and vim.api.nvim_win_is_valid(state.win)
end

local function close()
	if M.is_open() then
		vim.api.nvim_win_close(state.win, true)
	end
	state.win = nil
end

local function forget()
	state.win = nil
	if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
		vim.api.nvim_buf_delete(state.buf, { force = true })
	end
	state.buf = nil
end

local function focus()
	vim.api.nvim_set_current_win(state.win)
	vim.cmd("startinsert")
end

local function start(arguments)
	local fresh = not state.buf or not vim.api.nvim_buf_is_valid(state.buf)
	if fresh then
		state.buf = vim.api.nvim_create_buf(false, true)
		vim.bo[state.buf].bufhidden = "hide"
		vim.bo[state.buf].filetype = "opencode"
	end
	state.win = vim.api.nvim_open_win(state.buf, true, geometry())
	if fresh then
		local command = { "opencode" }
		vim.list_extend(command, arguments or {})
		-- Only clear the state when this exact session ends, so a restart does
		-- not drop the session that replaced it.
		local session = state.buf
		vim.fn.termopen(command, {
			on_exit = function()
				vim.schedule(function()
					if state.buf == session then
						forget()
					end
				end)
			end,
		})
		vim.keymap.set("t", "<C-q>", close, { buffer = state.buf, desc = "Close opencode" })
	end
	vim.cmd("startinsert")
end

---Open opencode in a floating terminal, or focus the running session.
---Arguments are passed to the CLI (for example `--continue` or `--model`).
---@param arguments? string[]
function M.open(arguments)
	if vim.fn.executable("opencode") ~= 1 then
		notify_error("opencode CLI (opencode) is required: see https://opencode.ai")
		return
	end
	local restart = arguments ~= nil and #arguments > 0
	if M.is_open() then
		if not restart then
			focus()
			return
		end
		close()
	end
	-- A flag starts a new conversation, so drop the previous session first.
	if restart then
		forget()
	end
	start(arguments)
end

---Toggle the window without losing the running session.
function M.toggle()
	if M.is_open() then
		close()
	else
		M.open()
	end
end

---Focus the window, starting a session when none exists.
function M.focus()
	if not M.is_open() then
		M.open()
		return
	end
	focus()
end

local function session_job()
	if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
		return nil
	end
	return vim.b[state.buf].terminal_job_id
end

---Send raw text to the running session.
---@param text string
function M.send(text)
	local job = session_job()
	if not job then
		vim.notify("opencode is not running", vim.log.levels.WARN, { title = title })
		return
	end
	if not M.is_open() then
		focus()
	end
	vim.api.nvim_chan_send(job, text)
	vim.cmd("startinsert")
end

---Insert an `@path` mention for a buffer so the CLI can read it.
---@param buf? integer
function M.mention(buf)
	buf = buf or vim.api.nvim_get_current_buf()
	local name = vim.api.nvim_buf_get_name(buf)
	if name == "" then
		vim.notify("This buffer has no file to mention", vim.log.levels.WARN, { title = title })
		return
	end
	local path, reason = guard.input_path(vim.fn.fnamemodify(name, ":."))
	if not path then
		vim.notify("Cannot mention this file: " .. reason, vim.log.levels.WARN, { title = title })
		return
	end
	M.send("@" .. path .. " ")
end

---Open the CLI command palette.
function M.select()
	M.send("/")
end

---Statusline component: non-empty while a session exists.
function M.status()
	if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
		return "opencode"
	end
	return ""
end

function M.setup()
	vim.api.nvim_create_user_command("OpenCode", function(command)
		M.open(command.fargs)
	end, { nargs = "*", desc = "Open opencode" })
	vim.api.nvim_create_user_command("OC", function(command)
		M.open(command.fargs)
	end, { nargs = "*", desc = "Open opencode" })

	-- <C-a>/<C-x> are reserved for the built-in dial (nazovim/dial.lua).
	vim.keymap.set({ "n", "x" }, "<leader>oa", function()
		M.mention()
	end, { desc = "Ask opencode" })
	vim.keymap.set({ "n", "x" }, "<leader>ox", M.select, { desc = "opencode command palette" })
	vim.keymap.set({ "n", "t" }, "<C-.>", M.toggle, { desc = "Toggle opencode" })
end

return M
