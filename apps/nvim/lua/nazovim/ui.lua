local M = {}

---Whether a buffer is suitable for lightweight editor decorations.
function M.normal(buf)
	return vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == ""
end

---Range of the active Visual selection. `ecol` is an inclusive byte column.
---`'<` and `'>` are only set after leaving Visual mode, so use the anchor mark.
---The last value is the Visual mode: "v", "V" or "\22".
function M.visual_range()
	local anchor = vim.fn.getpos("v")
	local cursor = vim.api.nvim_win_get_cursor(0)
	local srow, scol = math.max(1, anchor[2]), math.max(0, anchor[3] - 1)
	local erow, ecol = math.max(1, cursor[1]), math.max(0, cursor[2])
	local line = vim.api.nvim_buf_get_lines(0, erow - 1, erow, false)[1] or ""
	ecol = math.min(ecol, math.max(0, #line - 1))
	if srow > erow or (srow == erow and scol > ecol) then
		srow, erow = erow, srow
		scol, ecol = ecol, scol
	end
	return srow, scol, erow, ecol, vim.fn.visualmode()
end

---Coalesce event bursts; run once with the latest editor state.
function M.throttle(ms, callback)
	local pending = false
	return function()
		if pending then
			return
		end
		pending = true
		vim.defer_fn(function()
			pending = false
			if vim.v.exiting == vim.NIL then
				callback()
			end
		end, ms)
	end
end

---Return visible line numbers across ordinary windows, grouped by buffer.
function M.visible()
	local buffers = {}
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		local buf = vim.api.nvim_win_get_buf(win)
		if M.normal(buf) and vim.api.nvim_win_get_config(win).relative == "" then
			buffers[buf] = buffers[buf] or {}
			vim.api.nvim_win_call(win, function()
				-- Bound work even when a closed fold spans a huge file.
				local row, last = vim.fn.line("w0"), vim.fn.line("w$")
				local budget = vim.api.nvim_win_get_height(win) * 2 + 20
				while row <= last and budget > 0 do
					buffers[buf][row] = true
					local fold_end = vim.fn.foldclosedend(row)
					row = fold_end >= row and fold_end + 1 or row + 1
					budget = budget - 1
				end
			end)
		end
	end
	return buffers
end

---Install a visible-range renderer, clearing stale marks on hidden buffers.
function M.decorate(name, ns, render)
	local previous = {}
	local function update()
		local visible = M.visible()
		for buf in pairs(previous) do
			if vim.api.nvim_buf_is_valid(buf) then
				vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
			end
		end
		for buf, rows in pairs(visible) do
			render(buf, rows)
		end
		previous = visible
	end
	local group = vim.api.nvim_create_augroup(name, { clear = true })
	vim.api.nvim_create_autocmd(
		{ "BufWinEnter", "WinScrolled", "TextChanged", "TextChangedI", "TabEnter", "ColorScheme", "VimResized" },
		{
			group = group,
			callback = M.throttle(50, update),
		}
	)
	update()
end

return M
