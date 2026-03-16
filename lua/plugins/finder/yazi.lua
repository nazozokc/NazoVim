---@type LazySpec
return {
	"mikavilpas/yazi.nvim",
	version = "*",
	cmd = { "Yazi", "Yazi cwd", "Yazi toggle" },
	dependencies = {
		{ "nvim-lua/plenary.nvim", lazy = true },
	},
	opts = {
		open_for_directories = false,
		open_multiple_tabs = true,
		change_neovim_cwd_on_close = false,
		floating_window_scaling_factor = 0.9,
		yazi_floating_window_winblend = 0,
		yazi_floating_window_border = "rounded",
		highlight_hovered_buffers_in_same_directory = true,
		keymaps = {
			show_help = "<f1>",
			open_file_in_vertical_split = "<c-v>",
			open_file_in_horizontal_split = "<c-x>",
			open_file_in_tab = "<c-t>",
			grep_in_directory = "<c-s>",
			replace_in_directory = "<c-g>",
			cycle_open_buffers = "<tab>",
			copy_relative_path_to_selected_files = "<c-y>",
			send_to_quickfix_list = "<c-q>",
			change_working_directory = "<c-\\>",
			open_and_pick_window = "<c-o>",
		},
		integrations = {
			grep_in_directory = function(directory)
				local ok = pcall(require, "telescope")
				if ok then
					local telescope = require("telescope")
					telescope.extensions.live_grep.live_grep({
						cwd = directory,
					})
				end
			end,
			replace_in_directory = function(directory)
				local ok = pcall(require, "grug-far")
				if ok then
					require("grug-far").open({
						cwd = directory,
					})
				end
			end,
		},
	},
	init = function()
		vim.g.loaded_netrwPlugin = 1
	end,
}
