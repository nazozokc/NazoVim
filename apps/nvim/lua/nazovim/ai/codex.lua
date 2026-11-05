local M = {}

local title = "Codex"
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

---Return whether the Codex window is visible.
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

---Open the Codex CLI in a floating terminal, reusing a hidden session if present.
function M.open()
	if M.is_open() then
		vim.api.nvim_set_current_win(state.win)
		vim.cmd("startinsert")
		return
	end
	if vim.fn.executable("codex") ~= 1 then
		notify_error("Codex CLI (codex) is required: npm install -g @openai/codex")
		return
	end
	local fresh = not state.buf or not vim.api.nvim_buf_is_valid(state.buf)
	if fresh then
		state.buf = vim.api.nvim_create_buf(false, true)
		vim.bo[state.buf].bufhidden = "hide"
		vim.bo[state.buf].filetype = "codex"
	end
	state.win = vim.api.nvim_open_win(state.buf, true, geometry())
	if fresh then
		local session = state.buf
		vim.fn.termopen({ "codex" }, {
			on_exit = function()
				vim.schedule(function()
					if state.buf == session then
						forget()
					end
				end)
			end,
		})
		vim.keymap.set("t", "<C-q>", close, { buffer = state.buf, desc = "Close Codex" })
	end
	vim.cmd("startinsert")
end

---Toggle the Codex window without losing the running session.
function M.toggle()
	if M.is_open() then
		close()
	else
		M.open()
	end
end

---Statusline component: non-empty while a session exists.
function M.status()
	if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
		return "codex"
	end
	return ""
end

function M.setup()
	vim.api.nvim_create_user_command("Codex", M.open, { desc = "Open the Codex CLI" })
	vim.api.nvim_create_user_command("CodexToggle", M.toggle, { desc = "Toggle the Codex CLI" })
end

return M
