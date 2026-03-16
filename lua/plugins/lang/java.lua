return {
	{
		"nvim-java/nvim-java",
		dependencies = {
			"neovim/nvim-lspconfig",
			"mfussenegger/nvim-dap", -- Debug プラグイン
			"MunifTanjim/nui.nvim", -- UI 補助
		},
		ft = { "java" },
		config = function()
			require("java").setup({
				jdtls = { version = "latest" }, -- jdtls のバージョン
				lombok = { enable = true }, -- Lombok 対応
				java_test = { enable = true }, -- テスト
				java_debug_adapter = { enable = true }, -- デバッグ
				spring_boot_tools = { enable = true }, -- Spring Boot
				jdk = { auto_install = true, version = "17" },
			})
			-- LSP を有効化
			require("lspconfig").jdtls.setup({})
		end,
	},
}
