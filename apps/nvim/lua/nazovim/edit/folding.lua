local M = {}

local function shiftwidth()
	return vim.bo.shiftwidth > 0 and vim.bo.shiftwidth or vim.bo.tabstop
end

---Fold expression: Treesitter when a parser is available, indentation otherwise.
function M.foldexpr(lnum)
	lnum = lnum or vim.v.lnum
	local ok, result = pcall(vim.treesitter.foldexpr, lnum)
	if ok and result ~= nil then
		return result
	end
	local indent = vim.fn.indent(lnum)
	return math.floor(indent / math.max(1, shiftwidth()))
end

---Fold text with a compact summary of the hidden lines.
function M.foldtext()
	local first = vim.fn.getline(vim.v.foldstart)
	local count = vim.v.foldend - vim.v.foldstart + 1
	local summary = vim.trim(first:gsub("^%s*", ""))
	if summary == "" then
		summary = "…"
	end
	return "▸ " .. summary .. "  (" .. count .. " lines)"
end

function M.setup()
	vim.opt.foldmethod = "expr"
	vim.opt.foldexpr = "v:lua.require'nazovim.edit.folding'.foldexpr()"
	vim.opt.foldtext = "v:lua.require'nazovim.edit.folding'.foldtext()"
	vim.opt.foldlevel = 99
	vim.opt.foldlevelstart = 99
	vim.opt.foldenable = true
	vim.opt.fillchars:append({ fold = " " })
end

return M
