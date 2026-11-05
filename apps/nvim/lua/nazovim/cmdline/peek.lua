local M = {}
local saved
function M.setup()
	local group = vim.api.nvim_create_augroup("NazoPeek", { clear = true })
	vim.api.nvim_create_autocmd("CmdlineChanged", {
		group = group,
		pattern = ":",
		callback = function()
			local win = vim.api.nvim_get_current_win()
			if saved and (not vim.api.nvim_win_is_valid(saved.win) or saved.win ~= win) then
				saved = nil
			end
			local line = vim.fn.getcmdline():match("^%s*(%d+)%s*$")
			if saved then
				vim.fn.winrestview(saved.view)
			end
			if not line then
				saved = nil
				return
			end
			saved = saved or { win = win, view = vim.fn.winsaveview() }
			local last = vim.api.nvim_buf_line_count(0)
			vim.api.nvim_win_set_cursor(win, { math.max(1, math.min(tonumber(line), last)), 0 })
			vim.cmd("redraw")
		end,
	})
	vim.api.nvim_create_autocmd("CmdlineLeave", {
		group = group,
		pattern = ":",
		callback = function()
			if saved and vim.api.nvim_win_is_valid(saved.win) then
				vim.api.nvim_win_call(saved.win, function()
					vim.fn.winrestview(saved.view)
				end)
			end
			saved = nil
		end,
	})
end
return M
