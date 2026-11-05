local M = {}
local history = {}
local highlight_ns = vim.api.nvim_create_namespace("NazoInputHighlights")

local function set_line(buf, value)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { value })
	vim.api.nvim_win_set_cursor(0, { 1, #value })
end

local function completion_matches(value, kind)
	if not kind or kind == "" then
		return {}
	end
	local ok, matches = pcall(vim.fn.getcompletion, value, kind)
	return ok and matches or {}
end

local function input_scope(opts)
	if opts.scope == "window" or opts.scope == "buffer" or opts.scope == "tabpage" then
		return { relative = "win", row = 1, col = 1 }
	elseif opts.scope == "line" then
		return { relative = "win", row = vim.fn.winline(), col = 0 }
	elseif opts.scope == "editor" or opts.scope == "project" then
		return {
			relative = "editor",
			row = math.max(0, math.floor((vim.o.lines - vim.o.cmdheight) / 2)),
			col = math.max(0, math.floor(vim.o.columns * 0.1)),
		}
	end
	return { relative = "cursor", row = 1, col = 0 }
end

local function update_highlights(buf, value, callback)
	vim.api.nvim_buf_clear_namespace(buf, highlight_ns, 0, -1)
	if type(callback) ~= "function" then
		return
	end
	local ok, ranges = pcall(callback, value)
	if not ok or type(ranges) ~= "table" then
		return
	end
	for _, range in ipairs(ranges) do
		local start_col, end_col, group = range[1], range[2], range[3]
		if
			type(start_col) == "number"
			and type(end_col) == "number"
			and type(group) == "string"
			and start_col >= 0
			and end_col > start_col
			and end_col <= #value
		then
			vim.api.nvim_buf_set_extmark(buf, highlight_ns, 0, start_col, {
				end_col = end_col,
				hl_group = group,
			})
		end
	end
end

local function open_input(opts, on_confirm)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].undolevels = -1
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { opts.default or "" })

	local width = math.max(40, vim.api.nvim_strwidth(opts.default or ""))
	width = math.min(width, math.max(1, math.floor(vim.o.columns * 0.9)))
	local position = input_scope(opts)
	local win = vim.api.nvim_open_win(buf, true, {
		relative = position.relative,
		row = position.row,
		col = position.col,
		width = width,
		height = 1,
		style = "minimal",
		border = "rounded",
		title = opts.prompt or "Input",
		title_pos = "left",
	})
	vim.wo[win].wrap = false
	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].signcolumn = "no"
	vim.api.nvim_win_set_cursor(win, { 1, #(opts.default or "") })

	local done, completion, history_position = false, nil, nil
	local function finish(value)
		if done then
			return
		end
		done = true
		if value and value ~= "" then
			history[#history + 1] = value
		end
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
		if vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_buf_delete(buf, { force = true })
		end
		on_confirm(value)
	end
	local function current_value()
		return vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
	end
	local function refresh_highlights()
		update_highlights(buf, current_value(), opts.highlight)
	end
	local function complete(direction)
		local current = current_value()
		if not completion or (current ~= completion.prefix and current ~= completion.values[completion.index]) then
			completion = { prefix = current, values = completion_matches(current, opts.completion), index = 0 }
		end
		if #completion.values == 0 then
			return
		end
		if completion.index == 0 and direction < 0 then
			completion.index = 1
		end
		completion.index = (completion.index + direction - 1) % #completion.values + 1
		set_line(buf, completion.values[completion.index])
		refresh_highlights()
	end
	local function move_history(direction)
		if #history == 0 then
			return
		end
		history_position = history_position or (#history + 1)
		history_position = math.max(1, math.min(#history + 1, history_position + direction))
		set_line(buf, history[history_position] or "")
		refresh_highlights()
	end

	local opts_map = { buffer = buf, silent = true, nowait = true }
	vim.keymap.set({ "i", "n" }, "<CR>", function()
		finish(current_value())
	end, opts_map)
	vim.keymap.set({ "i", "n" }, "<Esc>", function()
		finish(nil)
	end, opts_map)
	vim.keymap.set("i", "<C-c>", function()
		finish(nil)
	end, opts_map)
	vim.keymap.set("i", "<Tab>", function()
		complete(1)
	end, opts_map)
	vim.keymap.set("i", "<S-Tab>", function()
		complete(-1)
	end, opts_map)
	vim.keymap.set({ "i", "n" }, "<Up>", function()
		move_history(-1)
	end, opts_map)
	vim.keymap.set({ "i", "n" }, "<Down>", function()
		move_history(1)
	end, opts_map)
	vim.api.nvim_create_autocmd("WinClosed", {
		pattern = tostring(win),
		once = true,
		callback = function()
			finish(nil)
		end,
	})
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		buffer = buf,
		callback = refresh_highlights,
	})
	refresh_highlights()
	vim.cmd.startinsert()
end

---Install a floating provider for Neovim's standard `vim.ui.input` API.
function M.setup()
	vim.ui.input = function(opts, on_confirm)
		if type(on_confirm) ~= "function" then
			error("vim.ui.input requires an on_confirm callback")
		end
		open_input(opts or {}, on_confirm)
	end
end

return M
