local M = {}

---Register the floating terminal command and its toggle mapping.
function M.setup()
	vim.api.nvim_create_user_command("ToggleTerm", function(opts)
		require("nazovim.lib.terminal").toggle(opts.count > 0 and opts.count or 1)
	end, { count = true, desc = "Toggle floating terminal" })
	vim.keymap.set("n", "<leader>t", "<cmd>ToggleTerm<cr>", { desc = "Toggle terminal" })
end

return M
