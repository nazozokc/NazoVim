local M = {}

local ns = vim.api.nvim_create_namespace("NazoIndent")

---Byte column of the innermost guide for a line, or nil when there is none.
function M.scope_col(line, shiftwidth)
	local indent = #(line:match("^%s*") or "")
	if indent < shiftwidth or shiftwidth <= 0 then
		return nil
	end
	local col = indent - shiftwidth
	if line:sub(col + 1, col + 1):match("%s") then
		return col
	end
	return nil
end

---Highlight the guide of the block that contains the cursor.
function M.update()
	local buf = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	if not vim.wo.list then
		return
	end
	local row = vim.api.nvim_win_get_cursor(0)[1]
	local line = vim.api.nvim_get_current_line()
	local shiftwidth = vim.bo.shiftwidth > 0 and vim.bo.shiftwidth or vim.bo.tabstop
	local col = M.scope_col(line, shiftwidth)
	if not col then
		return
	end
	vim.api.nvim_buf_set_extmark(buf, ns, row - 1, col, {
		virt_text = { { "│", "NazoIndentScope" } },
		virt_text_pos = "overlay",
		priority = 20,
	})
end

function M.setup()
	-- `leadmultispace` draws one guide per tabstop of leading whitespace.
	-- NazoVim keeps tabstop == shiftwidth == 2, so guides land on indent levels.
	vim.opt.list = true
	vim.opt.listchars = { leadmultispace = "│ ", extends = "›", precedes = "‹", nbsp = "␣" }
	vim.api.nvim_set_hl(0, "NazoIndentScope", { link = "Special", default = true })
	local group = vim.api.nvim_create_augroup("NazoIndent", { clear = true })
	vim.api.nvim_create_autocmd(
		{ "CursorMoved", "CursorMovedI", "WinScrolled", "BufEnter", "ColorScheme" },
		{ group = group, callback = M.update }
	)
end

return M
