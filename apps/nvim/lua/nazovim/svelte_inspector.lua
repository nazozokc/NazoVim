local M = {}

local function open_location(file, line, column)
	if type(file) ~= "string" or file == "" then
		return false, "file path is required"
	end
	local path = vim.fn.fnamemodify(file, ":p")
	if vim.fn.filereadable(path) == 0 then
		return false, "file does not exist: " .. path
	end
	line = math.max(1, math.floor(tonumber(line) or 1))
	column = math.max(1, math.floor(tonumber(column) or 1))
	vim.cmd.edit({ args = { path }, mods = { keepjumps = true } })
	local row = math.min(line, vim.api.nvim_buf_line_count(0))
	local text = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ""
	local byte_column = vim.str_byteindex(text, "utf-32", column - 1, false)
	vim.api.nvim_win_set_cursor(0, { row, math.min(byte_column, #text) })
	vim.cmd("normal! zz")
	return true
end

function M.open_json(payload)
	local ok, location = pcall(vim.json.decode, payload)
	if not ok or type(location) ~= "table" then
		return "invalid location payload"
	end
	local opened, err = open_location(location.file, location.line, location.column)
	return opened and "opened" or (err or "could not open location")
end

function M.setup()
	local server = vim.v.servername
	if server == "" then
		server = vim.fn.stdpath("run") .. "/nazovim-" .. vim.fn.getpid() .. ".sock"
		vim.fn.serverstart(server)
	end
	vim.env.NAZOVIM_NVIM_SERVER = server
	local launcher = vim.fn.stdpath("config") .. "/bin/nazovim-open-location"
	if vim.fn.executable(launcher) == 1 then
		vim.env.LAUNCH_EDITOR = launcher
	end
	vim.api.nvim_create_user_command("NazoOpenLocation", function(opts)
		local file, line, column = opts.args:match("^(.*):(%d+):(%d+)$")
		if not file then
			file, line = opts.args:match("^(.*):(%d+)$")
		end
		file = file or opts.args
		local ok, err = open_location(file, line, column)
		if not ok then
			vim.notify(err, vim.log.levels.ERROR, { title = "NazoVim Svelte Inspector" })
		end
	end, { nargs = "+", complete = "file", desc = "Open a file location from the browser inspector" })
end

return M
