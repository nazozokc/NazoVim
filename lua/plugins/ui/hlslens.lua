-- lua/plugins/hlslens.lua
return {
	"kevinhwang91/nvim-hlslens",
	event = { "BufReadPost", "BufNewFile" }, -- 必要に応じて
	config = function()
		local hlslens = require("hlslens")

		hlslens.setup({
			calm_down = true,
			nearest_only = true,
			nearest_float_when = "auto",
			enable_incsearch = true,
		})

		-- Auto activate hlslens on search
		local opts = { noremap = true, silent = true }

		-- Show count after n/N movement
		vim.api.nvim_set_keymap(
			"n",
			"n",
			[[<Cmd>execute('normal! ' . v:count1 . 'n')<CR><Cmd>lua require('hlslens').start()<CR>]],
			opts
		)
		vim.api.nvim_set_keymap(
			"n",
			"N",
			[[<Cmd>execute('normal! ' . v:count1 . 'N')<CR><Cmd>lua require('hlslens').start()<CR>]],
			opts
		)

		-- Same for * and #
		vim.api.nvim_set_keymap("n", "*", [[*<Cmd>lua require('hlslens').start()<CR>]], opts)
		vim.api.nvim_set_keymap("n", "#", [[#<Cmd>lua require('hlslens').start()<CR>]], opts)

		-- Toggle details with <Leader>l
		vim.api.nvim_set_keymap("n", "<Leader>l", "<Cmd>lua require('hlslens').toggle_virtual_text()<CR>", opts)
	end,
}
