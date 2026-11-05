local M = {}
local branches, pending = {}, {}

local function refresh_branch()
	local buf = vim.api.nvim_get_current_buf()
	if not require("nazovim.lib.ui").normal(buf) or vim.fn.executable("git") == 0 then
		return
	end
	local name = vim.api.nvim_buf_get_name(buf)
	local dir = name == "" and vim.fn.getcwd() or vim.fs.dirname(name)
	vim.b[buf].nazovim_git_dir = dir
	if pending[dir] then
		return
	end
	pending[dir] = true
	vim.system({ "git", "-C", dir, "rev-parse", "--abbrev-ref", "HEAD" }, { text = true }, function(result)
		vim.schedule(function()
			pending[dir] = nil
			branches[dir] = result.code == 0 and vim.trim(result.stdout) or ""
			vim.cmd.redrawstatus()
		end)
	end)
end

---Cached branch name for a buffer; never performs I/O during redraw.
function M.branch(buf)
	return branches[vim.b[buf].nazovim_git_dir] or ""
end

---Keep branch metadata fresh without blocking the statusline renderer.
function M.setup()
	local group = vim.api.nvim_create_augroup("NazoStatuslineGit", { clear = true })
	vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "FocusGained", "TermClose", "DirChanged" }, {
		group = group,
		callback = require("nazovim.lib.ui").throttle(100, refresh_branch),
	})
	refresh_branch()
end

return M
