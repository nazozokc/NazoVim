vim.opt.rtp:prepend("apps/nvim")
local quickstart = require("nazovim.quickstart")
local original_list_uis = vim.api.nvim_list_uis
vim.api.nvim_list_uis = function()
	return { {} }
end
vim.api.nvim_create_user_command("NazoPlug", function() end, { nargs = "*" })
quickstart.setup({ by_name = {} })
vim.api.nvim_exec_autocmds("VimEnter", {})
assert(vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] == "NazoVim")
assert(vim.fn.maparg("o", "n") ~= "")
assert(vim.fn.exists(":NazoHelp") == 2)
local original_input = vim.ui.input
local path = vim.fn.tempname() .. " file.txt"
vim.ui.input = function(_, callback)
	callback(path)
end
quickstart.open_file()
assert(vim.api.nvim_buf_get_name(0) == path)
vim.ui.input = original_input
vim.cmd("enew")
assert(vim.bo.buftype == "")
vim.api.nvim_list_uis = original_list_uis
print("quickstart: fallback dashboard and empty buffer passed")
vim.cmd("qall!")
