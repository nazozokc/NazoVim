return {
	"sindrets/diffview.nvim",
	cmd = { "DiffviewOpen", "DiffviewFileHistory" },
	keys = {
		{ "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Diff: Open" },
		{ "<leader>gh", "<cmd>DiffviewFileHistory %<cr>", desc = "Diff: File History" },
		{ "<leader>gH", "<cmd>DiffviewFileHistory<cr>", desc = "Diff: Branch History" },
		{ "<leader>gc", "<cmd>DiffviewClose<cr>", desc = "Diff: Close" },
	},
	config = function()
		local actions = require("diffview.actions")

		require("diffview").setup({
			enhanced_diff_hl = true,
			show_help_hints = false,
			watch_index = true,

			view = {
				default = {
					layout = "diff2_vertical",
					disable_diagnostics = true,
				},
				merge_tool = {
					layout = "diff3_horizontal",
					disable_diagnostics = true,
					winbar_info = true,
				},
				file_history = {
					layout = "diff2_vertical",
					disable_diagnostics = true,
				},
			},

			file_panel = {
				listing_style = "tree",
				tree_options = {
					flatten_dirs = true,
					folder_statuses = "only_folded",
				},
				win_config = {
					position = "left",
					width = 30,
				},
			},

			file_history_panel = {
				win_config = {
					position = "bottom",
					height = 12,
				},
			},

			hooks = {
				diff_buf_read = function(_bufnr)
					vim.opt_local.wrap = false
					vim.opt_local.relativenumber = false
				end,
			},

			keymaps = {
				disable_defaults = false,
				view = {
					{ "n", "<leader>co", actions.conflict_choose("ours"), { desc = "Choose OURS" } },
					{ "n", "<leader>ct", actions.conflict_choose("theirs"), { desc = "Choose THEIRS" } },
					{ "n", "<leader>ca", actions.conflict_choose("all"), { desc = "Choose ALL" } },
					{ "n", "dx", actions.conflict_choose("none"), { desc = "Delete conflict" } },
				},
			},
		})
	end,
}
