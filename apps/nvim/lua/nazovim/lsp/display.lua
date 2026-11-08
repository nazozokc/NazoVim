local M = {}

local title = "NazoVim LSP"

local function notify(message, level)
	vim.notify(message, level or vim.log.levels.INFO, { title = title })
end

---Toggle inlay hints for the current buffer.
function M.toggle_inlay_hints()
	local buf = vim.api.nvim_get_current_buf()
	local enable = not vim.lsp.inlay_hint.is_enabled({ bufnr = buf })
	vim.lsp.inlay_hint.enable(enable, { bufnr = buf })
	notify("Inlay hints: " .. (enable and "on" or "off"))
end

---Toggle semantic token highlighting for the current buffer.
function M.toggle_semantic_tokens()
	local buf = vim.api.nvim_get_current_buf()
	local enable = not vim.lsp.semantic_tokens.is_enabled({ bufnr = buf })
	vim.lsp.semantic_tokens.enable(enable, { bufnr = buf })
	notify("Semantic tokens: " .. (enable and "on" or "off"))
end

---Toggle code lens rendering for the current buffer.
function M.toggle_codelens()
	local buf = vim.api.nvim_get_current_buf()
	local enable = not vim.lsp.codelens.is_enabled({ bufnr = buf })
	vim.lsp.codelens.enable(enable, { bufnr = buf })
	notify("Code lens: " .. (enable and "on" or "off"))
end

---Register the non buffer-local display commands.
function M.setup()
	vim.api.nvim_create_user_command("NazoLspInlayHints", M.toggle_inlay_hints, {
		desc = "Toggle inlay hints",
	})
	vim.api.nvim_create_user_command("NazoLspSemanticTokens", M.toggle_semantic_tokens, {
		desc = "Toggle semantic tokens",
	})
	vim.api.nvim_create_user_command("NazoLspCodeLens", M.toggle_codelens, {
		desc = "Toggle code lens",
	})
end

return M
