return {
	"nvim-neotest/neotest",
	cmd = { "Neotest" },
	dependencies = {
		"nvim-neotest/neotest-jest",
		"marilari88/neotest-vitest",
		"thenbe/neotest-playwright",
	},
	keys = {

		{
			"<leader>tr",
			function()
				require("neotest").run.run()
			end,
			desc = "Run nearest test",
		},
		{
			"<leader>tR",
			function()
				require("neotest").run.run(vim.fn.getcwd())
			end,
			desc = "Run all tests",
		},
		{
			"<leader>tf",
			function()
				require("neotest").run.run(vim.fn.expand("%"))
			end,
			desc = "Run test file",
		},
		{
			"<leader>to",
			function()
				require("neotest").output.open()
			end,
			desc = "Toggle test output",
		},
	},
	opts = function(_, opts)
		opts.adapters = opts.adapters or {}

		table.insert(
			opts.adapters,
			require("neotest-jest")({
				jestCommand = "npm test --",
			})
		)

		table.insert(opts.adapters, require("neotest-vitest"))

		table.insert(
			opts.adapters,
			require("neotest-playwright").adapter({
				options = {
					persist_project_selection = true,
				},
			})
		)
	end,
}
