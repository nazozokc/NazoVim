local map = vim.keymap.set

-- UI / Toggle
map("n", "<leader>h", ":nohlsearch<CR>", { desc = "Clear search highlight" })
-- `<leader>e` shows the diagnostic float; `lsp/diagnostics.lua` owns it and
-- `<leader>xx` lists every workspace diagnostic.

-- NazoVim picker
map("n", "<leader><leader>", function()
	require("nazovim.search.picker").files()
end, { desc = "Files" })

map("n", "<leader>/", function()
	require("nazovim.search.picker").grep()
end, { desc = "Live Grep" })

map("n", "<leader>b", function()
	require("nazovim.search.picker").buffers()
end, { desc = "Buffers" })

map("n", "<leader>r", function()
	require("nazovim.search.picker").recent()
end, { desc = "Recent Files" })
