local M = {}
local ns = vim.api.nvim_create_namespace("NazoScrollbar")
local scratch, overlay
local busy = false

local function close()
	if overlay and vim.api.nvim_win_is_valid(overlay) then
		vim.api.nvim_win_close(overlay, true)
	end
	overlay = nil
end

---Build a proportional line overview: viewport thumb plus severity markers.
function M.layout(total, top, bottom, height, diagnostics)
	local function position(line)
		return math.min(height - 1, math.max(0, math.floor((line - 1) / math.max(1, total) * height)))
	end
	local first, last = position(top), position(bottom)
	local rows = {}
	for row = 0, height - 1 do
		rows[row + 1] = {
			text = row >= first and row <= last and "█" or "│",
			hl = row >= first and row <= last and "PmenuThumb" or "NonText",
		}
	end
	local severity = {}
	for _, diagnostic in ipairs(diagnostics) do
		local row = position(diagnostic.lnum + 1) + 1
		local level = diagnostic.severity or vim.diagnostic.severity.ERROR
		if not severity[row] or level < severity[row] then
			severity[row] = level
			rows[row] = {
				text = "●",
				hl = ({ "DiagnosticError", "DiagnosticWarn", "DiagnosticInfo", "DiagnosticHint" })[level],
			}
		end
	end
	return rows
end

---Refresh one reusable overlay for the active ordinary window.
function M.update()
	if busy then
		return
	end
	busy = true
	local win = vim.api.nvim_get_current_win()
	local buf = vim.api.nvim_win_get_buf(win)
	local height, width = vim.api.nvim_win_get_height(win), vim.api.nvim_win_get_width(win)
	local total = vim.api.nvim_buf_line_count(buf)
	if
		vim.api.nvim_win_get_config(win).relative ~= ""
		or not require("nazovim.lib.ui").normal(buf)
		or height < 3
		or width < 10
		or total <= height
	then
		close()
		busy = false
		return
	end
	local view = vim.fn.getwininfo(win)[1]
	local rows = M.layout(total, view.topline, view.botline, height, vim.diagnostic.get(buf))
	if not scratch or not vim.api.nvim_buf_is_valid(scratch) then
		scratch = vim.api.nvim_create_buf(false, true)
	end
	local lines = {}
	for _, row in ipairs(rows) do
		lines[#lines + 1] = row.text
	end
	vim.api.nvim_buf_set_lines(scratch, 0, -1, false, lines)
	vim.api.nvim_buf_clear_namespace(scratch, ns, 0, -1)
	for row, item in ipairs(rows) do
		vim.api.nvim_buf_set_extmark(scratch, ns, row - 1, 0, { end_col = #item.text, hl_group = item.hl })
	end
	local config = {
		relative = "win",
		win = win,
		row = 0,
		col = width - 1,
		width = 1,
		height = height,
		style = "minimal",
		focusable = false,
		zindex = 40,
		noautocmd = true,
	}
	if overlay and vim.api.nvim_win_is_valid(overlay) then
		vim.api.nvim_win_set_config(overlay, config)
	else
		overlay = vim.api.nvim_open_win(scratch, false, config)
		vim.wo[overlay].winhighlight = "Normal:Normal"
	end
	busy = false
end

---Replace both scrollbar plugins with a single event-driven active-window overview.
function M.setup()
	local group = vim.api.nvim_create_augroup("NazoScrollbar", { clear = true })
	local update = require("nazovim.lib.ui").throttle(40, M.update)
	vim.api.nvim_create_autocmd({
		"WinScrolled",
		"WinEnter",
		"BufEnter",
		"TabEnter",
		"VimResized",
		"WinResized",
		"DiagnosticChanged",
		"TextChanged",
		"TextChangedI",
		"ColorScheme",
	}, {
		group = group,
		callback = function()
			if not busy then
				update()
			end
		end,
	})
	vim.api.nvim_create_autocmd("WinClosed", {
		group = group,
		callback = function(args)
			-- Ignore decoration windows; their lifecycle must not feed another redraw loop.
			if not busy and tonumber(args.match) ~= overlay then
				update()
			end
		end,
	})
	vim.api.nvim_create_autocmd("VimLeavePre", { group = group, callback = close })
	M.update()
end

return M
