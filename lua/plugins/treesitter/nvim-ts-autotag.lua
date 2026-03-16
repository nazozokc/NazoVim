return {
	"windwp/nvim-ts-autotag",
	ft = { "html", "jsx", "tsx", "vue", "svelte", "astro" },
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
	},
	config = function()
		require("nvim-ts-autotag").setup({
			enable = true,

			-- 開始タグ変更時に終了タグも追従
			enable_rename = true,

			-- <div> → </div> を自動生成
			enable_close = true,

			-- </ を打った瞬間の補完はしない（誤爆防止）
			enable_close_on_slash = false,
		})
	end,
}
