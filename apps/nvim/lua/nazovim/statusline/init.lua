local M = {}
local git = require("nazovim.statusline.git")
local diagnostics = {}
local modes = {
	n = "NORMAL",
	i = "INSERT",
	v = "VISUAL",
	V = "V-LINE",
	["\22"] = "V-BLOCK",
	c = "COMMAND",
	R = "REPLACE",
	t = "TERMINAL",
	s = "SELECT",
}

local function escape(value)
	return tostring(value):gsub("[\r\n]", " "):gsub("%%", "%%%%")
end

---Render a statusline using cached metadata; never perform I/O during redraw.
function M.render()
	local buf = vim.api.nvim_get_current_buf()
	local mode = modes[vim.api.nvim_get_mode().mode:sub(1, 1)] or "NORMAL"
	local branch = vim.b[buf].gitsigns_head or git.branch(buf)
	local diff = vim.b[buf].nazovim_git_status or vim.b[buf].gitsigns_status or ""
	local counts = diagnostics[buf] or {}
	local diag = {}
	for severity, label in ipairs({ "E", "W", "I", "H" }) do
		if (counts[severity] or 0) > 0 then
			diag[#diag + 1] = label .. counts[severity]
		end
	end
	return "%#StatusLine# "
		.. mode
		.. (branch ~= "" and " │ " .. escape(branch) or "")
		.. (diff ~= "" and " " .. escape(diff) or "")
		.. " │ %<%f %m%r "
		.. table.concat(diag, " ")
		.. "%= "
		.. escape(vim.bo[buf].fileencoding ~= "" and vim.bo[buf].fileencoding or vim.o.encoding)
		.. " │ "
		.. escape(vim.bo[buf].fileformat)
		.. " │ %y │ %p%% │ %l:%c "
end

---Enable the global statusline and event-driven metadata updates.
function M.setup()
	vim.o.laststatus = 3
	vim.o.statusline = "%!v:lua.require'nazovim.statusline'.render()"
	local group = vim.api.nvim_create_augroup("NazoStatusline", { clear = true })
	vim.api.nvim_create_autocmd("DiagnosticChanged", {
		group = group,
		callback = function(args)
			diagnostics[args.buf] = vim.diagnostic.count(args.buf)
			vim.cmd.redrawstatus()
		end,
	})
	vim.api.nvim_create_autocmd("BufWipeout", {
		group = group,
		callback = function(args)
			diagnostics[args.buf] = nil
		end,
	})
	vim.api.nvim_create_autocmd("ModeChanged", {
		group = group,
		callback = function()
			vim.cmd.redrawstatus()
		end,
	})
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		diagnostics[buf] = vim.diagnostic.count(buf)
	end
	git.setup()
end

return M
