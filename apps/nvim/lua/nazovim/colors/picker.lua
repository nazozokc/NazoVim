local M = {}
local mark_ns = vim.api.nvim_create_namespace("NazoColorPickerTarget")
local palette_ns = vim.api.nvim_create_namespace("NazoColorPickerPalette")
local columns, rows = 12, 9

local function color_value(row, column)
	local hue = column * 30 / 60
	local saturation, lightness = 0.82, 0.2 + row * 0.075
	local chroma = (1 - math.abs(2 * lightness - 1)) * saturation
	local x = chroma * (1 - math.abs(hue % 2 - 1))
	local m = lightness - chroma / 2
	local rgb = {
		{ chroma, x, 0 },
		{ x, chroma, 0 },
		{ 0, chroma, x },
		{ 0, x, chroma },
		{ x, 0, chroma },
		{ chroma, 0, x },
	}
	local channels = rgb[math.floor(hue) + 1]
	local r = math.floor((channels[1] + m) * 255 + 0.5)
	local g = math.floor((channels[2] + m) * 255 + 0.5)
	local b = math.floor((channels[3] + m) * 255 + 0.5)
	return r * 65536 + g * 256 + b
end

local function as_hex(color)
	return string.format("#%06x", color)
end

local function locate_color(buf, row, cursor_col)
	local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
	local parse = require("nazovim.colors.lib.parse").parse
	local best
	local function consider(first, value, after)
		local start_col, end_col = first - 1, after - 1
		if cursor_col >= start_col and cursor_col < end_col and parse(value) then
			if not best or end_col - start_col > best.end_col - best.start_col then
				best = { start_col = start_col, end_col = end_col, value = value }
			end
		end
	end
	for first, value, after in line:gmatch("()(#%x+)()") do
		consider(first, value, after)
	end
	for first, value, after in line:gmatch("()(%a+%b())()") do
		consider(first, value, after)
	end
	for first, value, after in line:gmatch("()([%a]+)()") do
		consider(first, value, after)
	end
	return best
end

local function capture_target(buf)
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	local found = locate_color(buf, row - 1, col)
	local opts = { right_gravity = false }
	if found then
		opts.end_row, opts.end_col, opts.end_right_gravity = row - 1, found.end_col, true
	end
	return vim.api.nvim_buf_set_extmark(buf, mark_ns, row - 1, found and found.start_col or col, opts)
end

local function apply_color(buf, mark, color)
	if not vim.api.nvim_buf_is_valid(buf) then
		vim.notify("The target buffer is no longer editable", vim.log.levels.WARN, { title = "NazoVim" })
		return
	end
	local details = vim.api.nvim_buf_get_extmark_by_id(buf, mark_ns, mark, { details = true })
	if #details == 0 then
		vim.notify("The color target no longer exists", vim.log.levels.WARN, { title = "NazoVim" })
		return
	end
	local row, col = details[1], details[2]
	local range = details[3] or {}
	vim.api.nvim_buf_del_extmark(buf, mark_ns, mark)
	if not vim.bo[buf].modifiable then
		vim.notify("The target buffer is no longer editable", vim.log.levels.WARN, { title = "NazoVim" })
		return
	end
	vim.api.nvim_buf_set_text(buf, row, col, range.end_row or row, range.end_col or col, { as_hex(color) })
end

local function open_palette(buf, mark)
	local palette = vim.api.nvim_create_buf(false, true)
	vim.bo[palette].buftype = "nofile"
	vim.bo[palette].bufhidden = "wipe"
	vim.bo[palette].modifiable = false
	local lines = {
		"Choose a color",
		string.rep("  ", columns),
		string.rep("  ", columns),
		string.rep("  ", columns),
		string.rep("  ", columns),
		string.rep("  ", columns),
		string.rep("  ", columns),
		string.rep("  ", columns),
		string.rep("  ", columns),
		string.rep("  ", columns),
		"Arrows: move  Enter: apply  i: enter hex  Esc: close",
	}
	vim.bo[palette].modifiable = true
	vim.api.nvim_buf_set_lines(palette, 0, -1, false, lines)
	vim.bo[palette].modifiable = false
	local width = math.min(54, math.max(columns * 2, vim.o.columns - 4))
	local win = vim.api.nvim_open_win(palette, true, {
		relative = "editor",
		row = math.max(0, math.floor((vim.o.lines - #lines) / 2)),
		col = math.max(0, math.floor((vim.o.columns - width) / 2)),
		width = width,
		height = #lines,
		style = "minimal",
		border = "rounded",
		title = " NazoVim Colors ",
		title_pos = "center",
	})
	vim.wo[win].cursorline = false
	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].signcolumn = "no"
	local selected_row, selected_column = 4, 6
	local function selected_color()
		return color_value(selected_row, selected_column)
	end
	local function refresh()
		local color = selected_color()
		vim.api.nvim_win_set_config(win, { title = " " .. as_hex(color) .. " " })
		vim.api.nvim_win_set_cursor(win, { selected_row + 2, selected_column * 2 })
	end
	local keep_target, target_deleted = false, false
	local function clear_target()
		if not target_deleted and vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_buf_del_extmark(buf, mark_ns, mark)
			target_deleted = true
		end
	end
	local function close(keep)
		keep_target = keep == true
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
		if not keep_target then
			clear_target()
		end
	end
	local function move(row_delta, column_delta)
		selected_row = (selected_row + row_delta) % rows
		selected_column = (selected_column + column_delta) % columns
		refresh()
	end
	local map_opts = { buffer = palette, silent = true, nowait = true }
	vim.keymap.set("n", "<Up>", function()
		move(-1, 0)
	end, map_opts)
	vim.keymap.set("n", "k", function()
		move(-1, 0)
	end, map_opts)
	vim.keymap.set("n", "<Down>", function()
		move(1, 0)
	end, map_opts)
	vim.keymap.set("n", "j", function()
		move(1, 0)
	end, map_opts)
	vim.keymap.set("n", "<Left>", function()
		move(0, -1)
	end, map_opts)
	vim.keymap.set("n", "h", function()
		move(0, -1)
	end, map_opts)
	vim.keymap.set("n", "<Right>", function()
		move(0, 1)
	end, map_opts)
	vim.keymap.set("n", "l", function()
		move(0, 1)
	end, map_opts)
	vim.keymap.set("n", "<Esc>", close, map_opts)
	vim.keymap.set("n", "q", close, map_opts)
	vim.keymap.set("n", "<CR>", function()
		local color = selected_color()
		close(true)
		apply_color(buf, mark, color)
	end, map_opts)
	vim.keymap.set("n", "i", function()
		local color = selected_color()
		vim.ui.input({ prompt = "Color (#RRGGBB): ", default = as_hex(color), scope = "editor" }, function(value)
			if not value then
				if vim.api.nvim_win_is_valid(win) then
					vim.api.nvim_set_current_win(win)
				end
				return
			end
			local parsed = require("nazovim.colors.lib.parse").parse(value)
			if not parsed then
				vim.notify("Invalid color value", vim.log.levels.ERROR, { title = "NazoVim" })
				if vim.api.nvim_win_is_valid(win) then
					vim.api.nvim_set_current_win(win)
				end
				return
			end
			close(true)
			apply_color(buf, mark, parsed)
		end)
	end, map_opts)
	for row = 0, rows - 1 do
		for column = 0, columns - 1 do
			local color = color_value(row, column)
			local group = "NazoPick" .. string.format("%06x", color)
			local red, green, blue = math.floor(color / 65536), math.floor(color / 256) % 256, color % 256
			local light = (red * 299 + green * 587 + blue * 114) > 128000
			vim.api.nvim_set_hl(0, group, { bg = color, fg = light and 0x111111 or 0xffffff })
			vim.api.nvim_buf_set_extmark(palette, palette_ns, row + 1, column * 2, {
				end_col = column * 2 + 2,
				hl_group = group,
			})
		end
	end
	vim.api.nvim_create_autocmd("WinClosed", {
		pattern = tostring(win),
		once = true,
		callback = function()
			if not keep_target then
				clear_target()
			end
		end,
	})
	refresh()
end

---Open the NazoVim color palette at the cursor and replace or insert a color literal.
function M.pick()
	local buf = vim.api.nvim_get_current_buf()
	if not vim.bo[buf].modifiable then
		vim.notify("The current buffer is not editable", vim.log.levels.WARN, { title = "NazoVim" })
		return
	end
	open_palette(buf, capture_target(buf))
end

---Register the color palette command.
function M.setup()
	vim.api.nvim_create_user_command("CccPick", M.pick, { desc = "Choose and insert a color" })
end

return M
