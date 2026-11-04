local map = vim.keymap.set

-- UI / Toggle
map("n", "<leader>h", ":nohlsearch<CR>", { desc = "Clear search highlight" })
map("n", "<leader>e", function()
	require("nazovim.lists").diagnostics()
end, { desc = "Workspace diagnostics" })

-- NazoVim picker
map("n", "<leader><leader>", function()
	require("nazovim.picker").files()
end, { desc = "Files" })

map("n", "<leader>/", function()
	require("nazovim.picker").grep()
end, { desc = "Live Grep" })

map("n", "<leader>b", function()
	require("nazovim.picker").buffers()
end, { desc = "Buffers" })

map("n", "<leader>r", function()
	require("nazovim.picker").recent()
end, { desc = "Recent Files" })
