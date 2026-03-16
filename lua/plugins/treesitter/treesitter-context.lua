-- ~/.config/nvim/lua/plugins/treesitter-context.lua
return {
	{
		"nvim-treesitter/nvim-treesitter-context",
		event = { "BufReadPost", "BufNewFile" },
		opts = {
			enable = true,
			max_lines = 3, -- 表示行数（2〜4が無難）
			trim_scope = "outer", -- 外側優先
			mode = "cursor", -- カーソル基準
			separator = nil, -- 線を引きたいなら "─"
		},
	},
}
