-- =========================
-- Debug (JS / TS) 軽量最適化
-- =========================
return {

	-- DAP 本体（常駐させない）
	{
		"mfussenegger/nvim-dap",
		event = "VeryLazy",
		config = function()
			local dap = require("dap")

			-- 無駄なログを出さない
			dap.set_log_level("ERROR")
		end,
		keys = {
			{ "<F5>",        function() require("dap").continue() end,          desc = "DAP Continue" },
			{ "<F10>",       function() require("dap").step_over() end,         desc = "DAP Step Over" },
			{ "<F11>",       function() require("dap").step_into() end,         desc = "DAP Step Into" },
			{ "<F12>",       function() require("dap").step_out() end,          desc = "DAP Step Out" },
			{ "<leader>db",  function() require("dap").toggle_breakpoint() end, desc = "Toggle Breakpoint" },
			{ "<leader>B",   function() require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: ")) end, desc = "Conditional Breakpoint" },
		},
	},

	-- DAP UI（自動で開かせない）
	{
		"rcarriga/nvim-dap-ui",
		dependencies = { "mfussenegger/nvim-dap" },
		keys = {
			{
				"<leader>du",
				function()
					require("dapui").toggle()
				end,
				desc = "DAP UI Toggle",
			},
		},
		config = function()
			require("dapui").setup({
				layouts = {
					{
						elements = {
							{ id = "scopes", size = 0.4 },
							{ id = "breakpoints", size = 0.2 },
							{ id = "stacks", size = 0.2 },
							{ id = "watches", size = 0.2 },
						},
						size = 40,
						position = "right",
					},
				},
				controls = { enabled = false }, -- ← 地味に重い
			})
		end,
	},

	-- vscode-js-debug（build しない＝超重要）
	{
		"microsoft/vscode-js-debug",
		lazy = true,
		build = "echo 'skip build'", -- ← これがないと地獄
	},

	-- JS / TS 用 DAP
	{
		"mxsdev/nvim-dap-vscode-js",
		ft = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
		dependencies = {
			"mfussenegger/nvim-dap",
			"microsoft/vscode-js-debug",
		},
		config = function()
			require("dap-vscode-js").setup({
				-- node デバッグだけで十分（Chromeは必要時だけ）
				adapters = { "pwa-node" },
			})

			local dap = require("dap")

			for _, lang in ipairs({ "javascript", "typescript" }) do
				dap.configurations[lang] = {
					{
						type = "pwa-node",
						request = "launch",
						name = "Launch file",
						program = "${file}",
						cwd = "${workspaceFolder}",
						console = "integratedTerminal",
						skipFiles = { "<node_internals>/**" },
					},
				}
			end
		end,
	},

	-- Virtual Text（最小構成）
	{
		"theHamsta/nvim-dap-virtual-text",
		event = "VeryLazy",
		opts = {
			enabled = true,
			enabled_commands = false, -- ← いらん
			highlight_changed_variables = false,
			show_stop_reason = true,
			commented = true, -- コード邪魔しない
		},
	},
}
