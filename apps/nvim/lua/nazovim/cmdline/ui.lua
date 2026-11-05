local M = {}
local buffer
local window

local function close()
	if window and vim.api.nvim_win_is_valid(window) then
		vim.api.nvim_win_close(window, true)
	end
	window = nil
end

local function content()
	local kind = vim.fn.getcmdtype()
	local prefix = ({ [":"] = "❯ ", ["/"] = "⌕↓ ", ["?"] = "⌕↑ " })[kind] or (kind .. " ")
	return prefix .. vim.fn.getcmdline()
end

local function draw()
	if vim.fn.getcmdtype() == "" then
		close()
		return
	end
	local text = content()
	local width = math.max(1, math.min(vim.fn.strdisplaywidth(text), vim.o.columns - 2))
	if not buffer or not vim.api.nvim_buf_is_valid(buffer) then
		buffer = vim.api.nvim_create_buf(false, true)
		vim.bo[buffer].buftype = "nofile"
		vim.bo[buffer].bufhidden = "hide"
		vim.bo[buffer].swapfile = false
	end
	vim.bo[buffer].modifiable = true
	vim.api.nvim_buf_set_lines(buffer, 0, -1, false, { text })
	vim.bo[buffer].modifiable = false
	local config = {
		relative = "editor",
		style = "minimal",
		border = "rounded",
		focusable = false,
		row = math.max(0, vim.o.lines - vim.o.cmdheight - 4),
		col = math.max(0, math.floor((vim.o.columns - width) / 2)),
		width = width,
		height = 1,
		zindex = 90,
	}
	if window and vim.api.nvim_win_is_valid(window) then
		vim.api.nvim_win_set_config(window, config)
	else
		window = vim.api.nvim_open_win(buffer, false, config)
		vim.wo[window].winhighlight = "Normal:NazoCmdline,FloatBorder:FloatBorder"
	end
end

function M.setup()
	vim.opt.cmdheight = 0
	vim.opt.wildmenu = true
	vim.opt.wildoptions = "pum"
	vim.api.nvim_set_hl(0, "NazoCmdline", { link = "NormalFloat", default = true })
	local group = vim.api.nvim_create_augroup("NazoCmdlineUi", { clear = true })
	vim.api.nvim_create_autocmd("CmdlineEnter", { group = group, callback = draw })
	vim.api.nvim_create_autocmd("CmdlineChanged", { group = group, callback = draw })
	vim.api.nvim_create_autocmd("CmdlineLeave", { group = group, callback = close })
	vim.api.nvim_create_autocmd("VimResized", { group = group, callback = draw })
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = group,
		callback = function()
			vim.api.nvim_set_hl(0, "NazoCmdline", { link = "NormalFloat", default = true })
		end,
	})
end

return M
