local M = {}

---Open Neovim's built-in code action picker for the current buffer and range.
function M.code_action()
	vim.lsp.buf.code_action()
end

---Register the standalone code action mapping.
function M.setup()
	vim.keymap.set("n", "ga", M.code_action, { desc = "Code Action" })
end

return M
