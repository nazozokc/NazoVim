return {
	-- 1. mini.ai（テキストオブジェクト、編集系なのでほぼすぐロード）
	{
		"echasnovski/mini.ai",
		version = false,
		event = "VeryLazy", -- 起動直後でなく、Lazyロード
		config = function()
			require("mini.ai").setup({ mappings = { around = "a", inside = "i" } })
		end,
	},

	-- 2. mini.surround（aiに依存するのでaiと同じタイミング）
	{
		"echasnovski/mini.surround",
		version = false,
		event = "VeryLazy",
		config = function()
			require("mini.surround").setup({
				mappings = { add = "sa", delete = "sd", replace = "sr", update_n_lines = "sn" },
			})
		end,
	},

	-- 3. mini.comment（コメント系は編集時にロード）
	{
		"echasnovski/mini.comment",
		version = false,
		event = "BufReadPre", -- バッファを開く直前に読み込む
		config = function()
			require("mini.comment").setup({ options = { ignore_blank_line = true, start_of_line = false } })
		end,
	},

	-- 4. mini.indentscope（見た目系、表示時に読み込み）
	{
		"echasnovski/mini.indentscope",
		version = false,
		event = "BufReadPost", -- バッファ読み込み後に描画
		config = function()
			require("mini.indentscope").setup({
				draw = {
					delay = 100,
					animation = function()
						return 0
					end,
				},
			})
		end,
	},

	-- 5. mini.jump（移動系、ノーマルモード入ったらロード）
	{
		"echasnovski/mini.jump",
		version = false,
		event = "CursorMoved", -- 最初のカーソル移動でロード
		config = function()
			require("mini.jump").setup({ mappings = { repeat_forward = ";", repeat_backward = "," } })
		end,
	},
}
