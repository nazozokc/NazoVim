-- =========================
-- Debug (JS / TS) lightweight config
-- =========================
return {

	-- DAP core (load on demand)
	{
		"mfussenegger/nvim-dap",
		event = "VeryLazy",
		config = function()
			local dap = require("dap")
			dap.set_log_level("ERROR")
			if require("nazovim.features").enabled("dap_ui") then
				require("nazovim.dap_ui").attach(dap)
			end
			if require("nazovim.features").enabled("dap_virtual_text") then
				require("nazovim.dap_virtual_text").attach(dap)
			end
		end,
		keys = {
			{
				"<F5>",
				function()
					require("dap").continue()
				end,
				desc = "DAP Continue",
			},
			{
				"<F10>",
				function()
					require("dap").step_over()
				end,
				desc = "DAP Step Over",
			},
			{
				"<F11>",
				function()
					require("dap").step_into()
				end,
				desc = "DAP Step Into",
			},
			{
				"<F12>",
				function()
					require("dap").step_out()
				end,
				desc = "DAP Step Out",
			},
			{
				"<leader>db",
				function()
					require("dap").toggle_breakpoint()
				end,
				desc = "Toggle Breakpoint",
			},
			{
				"<leader>du",
				function()
					require("nazovim.dap_ui").toggle()
				end,
				desc = "Toggle Debugger Panel",
			},
			{
				"<leader>B",
				function()
					require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: "))
				end,
				desc = "Conditional Breakpoint",
			},
		},
	},

	-- vscode-js-debug (skip build)
	{
		"microsoft/vscode-js-debug",
		lazy = true,
		build = "echo 'skip build'",
	},

	-- JS / TS DAP
	{
		"mxsdev/nvim-dap-vscode-js",
		ft = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
		dependencies = {
			"mfussenegger/nvim-dap",
			"microsoft/vscode-js-debug",
		},
		config = function()
			require("dap-vscode-js").setup({
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
}
