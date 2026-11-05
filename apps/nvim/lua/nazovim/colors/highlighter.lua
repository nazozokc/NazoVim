local M = {}

---Register commands that enable or disable the built-in color-literal preview.
function M.setup()
	vim.api.nvim_create_user_command("CccHighlighterEnable", function()
		require("nazovim.colors").enable()
	end, { desc = "Enable color previews" })
	vim.api.nvim_create_user_command("CccHighlighterDisable", function()
		require("nazovim.colors").disable()
	end, { desc = "Disable color previews" })
end

return M
