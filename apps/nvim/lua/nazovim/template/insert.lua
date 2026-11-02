local expand = require("nazovim.template.expand")
local store = require("nazovim.template.store")

local M = {}

---Insert a template into the current buffer, or open a named destination first.
function M.insert(name, destination)
	local ft = destination and vim.filetype.match({ filename = destination }) or vim.bo.filetype
	local selected = store.resolve(name, false, ft)
	local lines = vim.fn.readfile(store.root() .. "/" .. selected)
	if destination then
		vim.cmd.edit({ args = { destination } })
	end
	if not vim.bo.modifiable or vim.bo.buftype ~= "" then
		error("Template requires a modifiable file buffer")
	end
	local expanded, cursor = expand.expand(lines, vim.api.nvim_buf_get_name(0))
	local empty = vim.api.nvim_buf_line_count(0) == 1 and vim.api.nvim_get_current_line() == ""
	local start = empty and 0 or vim.api.nvim_win_get_cursor(0)[1]
	vim.api.nvim_buf_set_lines(0, start, empty and 1 or start, false, expanded)
	if cursor then
		vim.api.nvim_win_set_cursor(0, { start + cursor[1], cursor[2] })
	end
end

return M
