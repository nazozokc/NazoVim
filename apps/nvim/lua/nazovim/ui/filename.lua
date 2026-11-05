local M = {}
local overlays = {}
local pending = false
local updating = false

local function clear()
	for _, overlay in pairs(overlays) do
		if vim.api.nvim_win_is_valid(overlay.win) then
			pcall(vim.api.nvim_win_close, overlay.win, true)
		end
		if vim.api.nvim_buf_is_valid(overlay.buf) then
			pcall(vim.api.nvim_buf_delete, overlay.buf, { force = true })
		end
	end
	overlays = {}
end

local function update()
	pending = false
	updating = true
	clear()
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		local config = vim.api.nvim_win_get_config(win)
		local buf = vim.api.nvim_win_get_buf(win)
		if config.relative == "" and vim.bo[buf].buftype == "" and vim.bo[buf].buflisted then
			local name = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t")
			if name == "" then
				name = "[No Name]"
			end
			local width = math.min(vim.api.nvim_win_get_width(win), vim.fn.strdisplaywidth(name) + 2)
			if width > 2 then
				local scratch = vim.api.nvim_create_buf(false, true)
				vim.api.nvim_buf_set_lines(scratch, 0, -1, false, { " " .. name .. " " })
				local ok, float = pcall(vim.api.nvim_open_win, scratch, false, {
					relative = "win",
					win = win,
					row = 0,
					col = vim.api.nvim_win_get_width(win) - width,
					width = width,
					height = 1,
					style = "minimal",
					focusable = false,
					zindex = 50,
				})
				if ok then
					vim.wo[float].winhighlight = "Normal:NormalFloat"
					overlays[win] = { win = float, buf = scratch }
				else
					vim.api.nvim_buf_delete(scratch, { force = true })
				end
			end
		end
	end
	updating = false
end

function M.setup()
	local group = vim.api.nvim_create_augroup("NazoFilename", { clear = true })
	vim.api.nvim_create_autocmd({ "BufEnter", "BufFilePost", "WinEnter", "WinClosed", "VimResized", "TabEnter" }, {
		group = group,
		callback = function()
			if pending or updating then
				return
			end
			pending = true
			vim.defer_fn(update, 50)
		end,
	})
	update()
end
return M
