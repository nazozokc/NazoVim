local M = {}

---Enable Neovim's native command-line popup completion.
function M.setup()
	vim.opt.wildmenu = true
	vim.opt.wildmode = "longest:full,full"
	vim.opt.wildoptions = "pum"
	vim.opt.wildignorecase = true

	if vim.fn.exists("*wildtrigger") == 1 then
		local group = vim.api.nvim_create_augroup("NazoVimCmdlineCompletion", { clear = true })
		vim.api.nvim_create_autocmd("CmdlineChanged", {
			group = group,
			pattern = { ":", "/", "?" },
			callback = function()
				vim.fn.wildtrigger()
			end,
		})
	end
end

return M
