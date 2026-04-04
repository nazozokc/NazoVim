local map = vim.keymap.set

-- UI / Toggle
map("n", "<leader>h", ":nohlsearch<CR>", { desc = "Clear search highlight" })
map("n", "<leader>t", ":ToggleTerm<CR>", { desc = "Toggle terminal" })
map("n", "<leader>so", ":AerialToggle!<CR>", { desc = "Toggle Aerial" })
map("n", "<F2>", function()
	require("snacks").zen.toggle()
end, { desc = "Toggle Zen Mode" })
map("n", "<leader>e", "<cmd>Trouble diagnostics toggle<cr>", { desc = "Toggle Trouble" })

-- LSP (Lspsaga / Actions)
map("n", "ga", "<cmd>Lspsaga code_action<CR>", { desc = "Code Action" })

map("n", "<leader>ca", function()
	require("actions-preview").code_actions()
end, { desc = "Code Action (preview)" })

-- Snacks.nvim (Picker / Zen)
map("n", "<leader><leader>", function()
	require("snacks.picker").files()
end, { desc = "Files" })

map("n", "<leader>/", function()
	require("snacks.picker").grep()
end, { desc = "Live Grep" })

map("n", "<leader>b", function()
	require("snacks.picker").buffers()
end, { desc = "Buffers" })

map("n", "<leader>r", function()
	require("snacks.picker").recent()
end, { desc = "Recent Files" })

map("n", "<leader>z", function()
	require("snacks").zen.toggle()
end, { desc = "Zen Mode" })

-- Dropbar.nvim
map("n", "<leader>;", function()
	require("dropbar.api").pick()
end, { desc = "Dropbar pick symbol" })
