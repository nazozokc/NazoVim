local M = {}

local guard = require("nazovim.ai.lib.guard")

local function notify(message, level)
	vim.notify(message, level, { title = "NazoVim Translate" })
end

local function clean_message(text)
	local redacted = guard.redact(text)
	return (redacted:gsub("[%z\1-\31\127]", " "))
end

local function show_result(lines)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].filetype = "text"
	vim.bo[buf].modifiable = false
	local width = 1
	for _, line in ipairs(lines) do
		width = math.max(width, vim.fn.strdisplaywidth(line))
	end
	width = math.min(width, math.max(20, math.floor(vim.o.columns * 0.8)))
	local height = math.max(1, math.min(#lines, math.floor(vim.o.lines * 0.6)))
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
		col = math.max(0, math.floor((vim.o.columns - width) / 2)),
		style = "minimal",
		border = "rounded",
		title = " Translation ",
		title_pos = "center",
	})
	vim.wo[win].wrap = true
	vim.keymap.set("n", "q", function()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end, { buffer = buf, nowait = true, silent = true, desc = "Close translation" })
	vim.keymap.set("n", "<Esc>", function()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end, { buffer = buf, nowait = true, silent = true, desc = "Close translation" })
end

---Translate text through the configured Translate Shell executable.
function M.translate(text, target)
	text = vim.trim(text or "")
	if text == "" then
		notify("There is no text to translate", vim.log.levels.WARN)
		return
	end
	if #text > 64 * 1024 then
		notify("Text is too large to translate (64 KiB maximum)", vim.log.levels.WARN)
		return
	end
	target = target or vim.g.nazovim_translate_target or "ja"
	if type(target) ~= "string" or not target:match("^[%w_%-]+$") then
		notify("Target language must be a language code", vim.log.levels.ERROR)
		return
	end
	local executable = vim.g.nazovim_translate_executable or "trans"
	if vim.fn.executable(executable) ~= 1 then
		notify(
			"Translate Shell (`trans`) is required; set g:nazovim_translate_executable to its path",
			vim.log.levels.ERROR
		)
		return
	end
	local translator = vim.g.nazovim_translate_provider or "google"
	if type(translator) ~= "string" or not translator:match("^[%w_%-]+$") then
		notify("Provider must contain only letters, numbers, `_` or `-`", vim.log.levels.ERROR)
		return
	end
	local source = vim.g.nazovim_translate_source
	if source ~= nil and source ~= "" then
		if type(source) ~= "string" or not source:match("^[%w_%-]+$") then
			notify("Source language must be a language code", vim.log.levels.ERROR)
			return
		end
	end
	local language_pair = (type(source) == "string" and source ~= "" and source or "") .. ":" .. target
	local timeout = math.max(5, math.min(300, math.floor(tonumber(vim.g.nazovim_translate_timeout) or 60)))
	vim.system({ executable, "--translators=" .. translator, "-brief", language_pair }, {
		stdin = text,
		text = true,
		timeout = timeout * 1000,
	}, function(result)
		vim.schedule(function()
			if result.code == 124 then
				notify("Translation timed out", vim.log.levels.ERROR)
				return
			end
			if result.code ~= 0 then
				local detail = vim.trim(result.stderr or "")
				notify(detail ~= "" and clean_message(detail) or "Translation command failed", vim.log.levels.ERROR)
				return
			end
			local stdout = result.stdout or ""
			if #stdout > 256 * 1024 then
				stdout = stdout:sub(1, 256 * 1024)
				notify("Translation output was truncated", vim.log.levels.WARN)
			end
			local output = vim.split(vim.trim(stdout), "\n", { plain = true })
			if #output == 0 or output[1] == "" then
				notify("Translation returned no text", vim.log.levels.WARN)
				return
			end
			if #output > 2000 then
				output = vim.list_slice(output, 1, 2000)
				output[#output + 1] = "[truncated by NazoVim]"
			end
			show_result(output)
		end)
	end)
end

local function line_range(first, last)
	return table.concat(vim.api.nvim_buf_get_lines(0, first - 1, last, false), "\n")
end

---Translate the current visual selection, preserving characterwise selections.
function M.translate_visual()
	local region = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = vim.fn.visualmode() })
	M.translate(table.concat(region, "\n"))
end

---Register `:NazoTranslate` and normal/visual `<leader>T` mappings.
function M.setup()
	vim.api.nvim_create_user_command("NazoTranslate", function(opts)
		local text = line_range(opts.line1, opts.line2)
		M.translate(text, opts.args ~= "" and opts.args or nil)
	end, { nargs = "?", range = true, desc = "Translate the selected text" })
	vim.keymap.set("n", "<Leader>T", function()
		M.translate(vim.api.nvim_get_current_line())
	end, { desc = "Translate line to Japanese" })
	vim.keymap.set("x", "<Leader>T", M.translate_visual, { desc = "Translate selection to Japanese" })
end

return M
