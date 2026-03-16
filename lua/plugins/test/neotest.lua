return {
	"nvim-neotest/neotest",
	cmd = { "Neotest" },
	dependencies = {
		"nvim-neotest/neotest-jest",
		"marilari88/neotest-vitest",
		"thenbe/neotest-playwright",
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
