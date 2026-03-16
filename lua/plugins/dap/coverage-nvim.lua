return {
	"andythigpen/nvim-coverage",
	dependencies = { "nvim-lua/plenary.nvim" },
	cmd = { "CoverageLoad", "CoverageSummary", "CoverageToggle", "CoverageHide" },
	config = function()
		require("coverage").setup({
			commands = true, -- :CoverageSummary などコマンドを作る
			auto_reload = true, -- カバレッジファイル変更で自動再読み込み
			highlights = {
				covered = { fg = "#C3E88D" },
				uncovered = { fg = "#F07178" },
			},
			signs = {
				covered = { hl = "CoverageCovered", text = "▎" },
				uncovered = { hl = "CoverageUncovered", text = "▎" },
			},
			summary = {
				min_coverage = 80.0, -- 80%未満のファイルを警告色
			},
		})
	end,
}
