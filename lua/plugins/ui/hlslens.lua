-- lua/plugins/hlslens.lua
return {
	"kevinhwang91/nvim-hlslens",
	event = { "BufReadPost", "BufNewFile" }, -- 必要に応じて
	config = function()
		local hlslens = require("hlslens")

		hlslens.setup({
			calm_down = true, -- ジャンプ時のちらつき減少
			nearest_only = true, -- 最寄りのハイライトだけ強調
			nearest_float_when = "auto", -- float 表示タイミング
			enable_incsearch = true, -- incsearch と連動
			build_position_cb = function(plist, idx, _)
				-- 上下分割/横分割で位置調整したいとき
				return require("hlslens/util").float_updown(plist, idx)
			end,
		})

		-- 検索時に hlslens を自動で発動させるマッピング
		local opts = { noremap = true, silent = true }

		-- n/N で移動したあとカウント表示
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

		-- * と # でも同様に
		vim.api.nvim_set_keymap("n", "*", [[*<Cmd>lua require('hlslens').start()<CR>]], opts)
		vim.api.nvim_set_keymap("n", "#", [[#<Cmd>lua require('hlslens').start()<CR>]], opts)

		-- <Leader>l で現在結果の詳細 toggle
		vim.api.nvim_set_keymap("n", "<Leader>l", "<Cmd>lua require('hlslens').toggle_virtual_text()<CR>", opts)
	end,
}
