local M = {}

---Create the missing parent directories for a buffer's file.
---@param buf integer
function M.ensure_directory(buf)
	if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= "" then
		return
	end
	local name = vim.api.nvim_buf_get_name(buf)
	if name == "" then
		return
	end
	local directory = vim.fs.dirname(name)
	if not directory or directory == "" or vim.fn.isdirectory(directory) == 1 then
		return
	end
	vim.fn.mkdir(directory, "p")
end

function M.setup()
	local group = vim.api.nvim_create_augroup("NazoQuickfile", { clear = true })
	vim.api.nvim_create_autocmd("BufWritePre", {
		group = group,
		desc = "Create missing parent directories before writing",
		callback = function(args)
			M.ensure_directory(args.buf)
		end,
	})
end

return M
