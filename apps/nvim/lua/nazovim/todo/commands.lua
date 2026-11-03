local M = {}

local function find_todos(loclist)
	return function()
		require("nazovim.todo").search(loclist)
	end
end

---Register project TODO search commands.
function M.setup()
	vim.api.nvim_create_user_command("TodoQuickFix", find_todos(false), { desc = "Find project TODOs" })
	vim.api.nvim_create_user_command(
		"TodoLocList",
		find_todos(true),
		{ desc = "Find project TODOs in a location list" }
	)
	vim.api.nvim_create_user_command("TodoTelescope", find_todos(false), { desc = "Find project TODOs (quickfix)" })
	vim.api.nvim_create_user_command("TodoTrouble", find_todos(false), { desc = "Find project TODOs (quickfix)" })
end

return M
