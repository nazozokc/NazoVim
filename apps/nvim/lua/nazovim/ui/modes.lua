local M = {}
local colors = {
	n = "#7e9cd8",
	i = "#98bb6c",
	v = "#c0a36e",
	V = "#c0a36e",
	["\22"] = "#c0a36e",
	c = "#957fb8",
	R = "#e46876",
	t = "#a3d4d5",
}

local function update()
	local color = colors[vim.api.nvim_get_mode().mode:sub(1, 1)] or colors.n
	vim.api.nvim_set_hl(0, "CursorLineNr", { fg = color, bold = true })
	vim.api.nvim_set_hl(0, "LineNr", { fg = color })
end

function M.setup()
	local group = vim.api.nvim_create_augroup("NazoModes", { clear = true })
	vim.api.nvim_create_autocmd({ "ModeChanged", "ColorScheme" }, { group = group, callback = update })
	update()
end
return M
