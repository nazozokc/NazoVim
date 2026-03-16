return {
	"vuki656/package-info.nvim",
	dependencies = { "MunifTanjim/nui.nvim" },
	ft = { "json" },
	config = function()
		require("package-info").setup({
			colors = {
				up_to_date = "#3C4048",
				outdated = "#d19a66",
			},
			icons = {
				enable = true,
				style = {
					up_to_date = "| ",
					outdated = "| ",
				},
			},
			autostart = true,
			hide_up_to_date = true,
			hide_unstable_versions = false,
			package_manager = (function()
				local root = vim.fn.getcwd()
				if vim.fn.filereadable(root .. "/pnpm-lock.yaml") == 1 then
					return "pnpm"
				elseif vim.fn.filereadable(root .. "/yarn.lock") == 1 then
					return "yarn"
				elseif vim.fn.filereadable(root .. "/bun.lockb") == 1 then
					return "bun"
				else
					return "npm"
				end
			end)(),
		})

		-- キーマップ
		local map = vim.keymap.set
		map("n", "<leader>ns", require("package-info").show, { desc = "Show package versions", silent = true })
		map("n", "<leader>nc", require("package-info").hide, { desc = "Hide package versions", silent = true })
		map("n", "<leader>nt", require("package-info").toggle, { desc = "Toggle package versions", silent = true })
		map("n", "<leader>nu", require("package-info").update, { desc = "Update package", silent = true })
		map("n", "<leader>nd", require("package-info").delete, { desc = "Delete package", silent = true })
		map("n", "<leader>ni", require("package-info").install, { desc = "Install new package", silent = true })
		map(
			"n",
			"<leader>np",
			require("package-info").change_version,
			{ desc = "Change package version", silent = true }
		)
	end,
}
