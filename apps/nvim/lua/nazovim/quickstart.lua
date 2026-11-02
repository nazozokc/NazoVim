local M = {}

function M.open_file()
	vim.ui.input({ prompt = "Open file: ", completion = "file" }, function(path)
		if path and path ~= "" then
			vim.cmd.edit({ args = { path } })
		end
	end)
end

local function show()
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].bufhidden = "wipe"
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
		"NazoVim",
		"",
		"  o  Open a file (Tab completes paths)",
		"  e  New empty file",
		"  h  Editing help",
		"  p  Install additional plugins",
		"  q  Quit",
		"",
		"Editing: i insert | Esc normal mode | :w save | :q quit",
		"Plugins are not installed yet. Press p to install them; a restart is required.",
	})
	vim.bo[buf].modifiable = false
	vim.api.nvim_win_set_buf(0, buf)
	local opts = { buffer = buf, silent = true, nowait = true }
	vim.keymap.set("n", "o", M.open_file, opts)
	vim.keymap.set("n", "e", "<cmd>enew<cr>", opts)
	vim.keymap.set("n", "h", "<cmd>help user-manual<cr>", opts)
	vim.keymap.set("n", "p", "<cmd>NazoPlug install<cr>", opts)
	vim.keymap.set("n", "q", "<cmd>quit<cr>", opts)
end

function M.setup(manager)
	vim.api.nvim_create_user_command("NazoHelp", function()
		vim.cmd.help("user-manual")
	end, { desc = "Open the Neovim user manual" })
	local snacks = manager.by_name and manager.by_name["snacks.nvim"]
	if snacks and vim.fn.isdirectory(snacks.dir) == 1 then
		return
	end
	vim.api.nvim_create_autocmd("VimEnter", {
		once = true,
		callback = function()
			if #vim.api.nvim_list_uis() == 0 or vim.fn.argc() ~= 0 then
				return
			end
			if vim.api.nvim_buf_get_name(0) ~= "" or vim.bo.buftype ~= "" or vim.bo.modified then
				return
			end
			show()
		end,
	})
end

return M
