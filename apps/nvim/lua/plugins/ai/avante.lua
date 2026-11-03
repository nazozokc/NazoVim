return {
	"yetone/avante.nvim",
	event = "VeryLazy",
	build = "make",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"MunifTanjim/nui.nvim",
		{ "ColinKennedy/mega.cmdparse", dependencies = { "ColinKennedy/mega.logging" } },
		"nvim-tree/nvim-web-devicons",
	},
	opts = {
		-- Provider設定: 環境変数 AVANTE_PROVIDER で上書き可能
		-- 利用可能: "claude", "openai", "copilot", "gemini", "ollama" 等
		provider = os.getenv("AVANTE_PROVIDER") or "claude",

		-- プロバイダー設定（ユーザーが各自で追記）
		-- 例:
		-- providers = {
		--   claude = {
		--     endpoint = "https://api.anthropic.com",
		--     model = "claude-sonnet-4-5-20250929",
		--   },
		--   openai = {
		--     endpoint = "https://api.openai.com/v1",
		--     model = "gpt-4o",
		--   },
		-- }
		providers = {},

		-- ファイル選択: snacks.nvimを使用
		file_selector = {
			provider = "snacks",
		},

		-- 入力プロバイダー: snacks.nvimを使用
		input = {
			provider = "snacks",
		},

		-- セレクター: snacks.nvimを使用
		selector = {
			provider = "snacks",
		},

		-- ウィンドウ設定
		windows = {
			position = "right",
			wrap = true,
			width = 30,
		},

		-- ビヘイビア
		behaviour = {
			auto_suggestions = false,
			auto_set_keymaps = true,
			auto_apply_diff_after_generation = false,
			support_paste_from_clipboard = false,
			minimize_diff = true,
			enable_token_counting = true,
			auto_approve_tool_permissions = true,
			auto_add_current_file = true,
		},

		-- キーマップ設定
		mappings = {
			ask = "<leader>aa",
			new_ask = "<leader>an",
			edit = "<leader>ae",
			refresh = "<leader>ar",
			focus = "<leader>af",
			stop = "<leader>aS",
			toggle = {
				default = "<leader>at",
				debug = "<leader>ad",
				selection = "<leader>aC",
				suggestion = "<leader>as",
				repomap = "<leader>aR",
			},
			files = {
				add_current = "<leader>ac",
				add_all_buffers = "<leader>aB",
			},
			select_model = "<leader>a?",
			select_history = "<leader>ah",
		},

		-- デバッグモード
		debug = false,
	},
}
