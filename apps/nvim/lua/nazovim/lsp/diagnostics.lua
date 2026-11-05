local M = {}

---Use Neovim's diagnostic lifecycle for current-line messages and wrapping.
function M.setup()
	vim.diagnostic.config({
		virtual_text = false,
		virtual_lines = { current_line = true },
		severity_sort = true,
		update_in_insert = false,
		float = { border = "rounded", source = "if_many" },
	})
end

return M
