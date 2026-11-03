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

local function line_indent(buf, row)
	local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
	return #(line:match("^%s*") or ""), line
end

---Rows spanned by the block at guide column `col` that contains `row`.
---Blank lines stay inside the block. `first`/`last` bound the scan so a
---cursor move does not walk a whole large file.
function M.block(buf, row, col, first, last)
	local total = vim.api.nvim_buf_line_count(buf)
	first = first or 1
	last = last or total
	local top = row
	while top > first do
		local indent, line = line_indent(buf, top - 1)
		if line:match("^%s*$") then
			top = top - 1
		elseif indent > col then
			top = top - 1
		else
			break
		end
	end
	local bottom = row
	while bottom < last do
		local indent, line = line_indent(buf, bottom + 1)
		if line:match("^%s*$") then
			bottom = bottom + 1
		elseif indent > col then
			bottom = bottom + 1
		else
			break
		end
	end
	return top, bottom
end

---Highlight the guide of the block that contains the cursor.
function M.update()
	local buf = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	if not vim.wo.list or not require("nazovim.ui").normal(buf) then
		return
	end
	local row = vim.api.nvim_win_get_cursor(0)[1]
	local line = vim.api.nvim_get_current_line()
	local shiftwidth = vim.bo.shiftwidth > 0 and vim.bo.shiftwidth or vim.bo.tabstop
	local col = M.scope_col(line, shiftwidth)
	if not col then
		return
	end
	-- Draw only the visible part; the block can span a whole file.
	local win_first, win_last = vim.fn.line("w0"), vim.fn.line("w$")
	local top, bottom = M.block(buf, row, col, win_first, win_last)
	for r = top, bottom do
		local _, text = line_indent(buf, r)
		vim.api.nvim_buf_set_extmark(buf, ns, r - 1, math.min(col, #text), {
			virt_text = { { "│", "NazoIndentScope" } },
			virt_text_pos = "overlay",
			virt_text_win_col = col,
			priority = 20,
		})
	end
end

function M.setup()
	-- `leadmultispace` draws one guide per tabstop of leading whitespace.
	-- NazoVim keeps tabstop == shiftwidth == 2, so guides land on indent levels.
	vim.opt.list = true
	vim.opt.listchars:append({ leadmultispace = "│ ", extends = "›", precedes = "‹" })
	vim.api.nvim_set_hl(0, "NazoIndentScope", { link = "Special", default = true })
	local group = vim.api.nvim_create_augroup("NazoIndent", { clear = true })
	vim.api.nvim_create_autocmd(
		{ "CursorMoved", "CursorMovedI", "WinScrolled", "BufEnter", "ColorScheme" },
		{ group = group, callback = M.update }
	)
end

return M
