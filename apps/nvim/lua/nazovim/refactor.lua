local M = {}

---Request refactoring code actions from attached language servers.
function M.run()
	vim.lsp.buf.code_action({
		context = {
			only = { "refactor" },
		},
	})
end

---Register a command and mapping for LSP refactor actions.
function M.setup()
	vim.keymap.set("n", "<leader>rR", M.run, { desc = "Refactor" })
	vim.api.nvim_create_user_command("NazoRefactor", M.run, { desc = "Select LSP refactoring action" })
end

return M
