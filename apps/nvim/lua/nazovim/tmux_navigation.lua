local M = {}

local directions = {
	{ key = "<C-h>", window = "h", pane = "-L", edge = "#{pane_at_left}", desc = "Navigate left" },
	{ key = "<C-j>", window = "j", pane = "-D", edge = "#{pane_at_bottom}", desc = "Navigate down" },
	{ key = "<C-k>", window = "k", pane = "-U", edge = "#{pane_at_top}", desc = "Navigate up" },
	{ key = "<C-l>", window = "l", pane = "-R", edge = "#{pane_at_right}", desc = "Navigate right" },
}

local function navigate(direction)
	if vim.env.TMUX and vim.env.TMUX ~= "" and vim.fn.executable("tmux") == 1 then
		local edge = vim.fn.systemlist({ "tmux", "display-message", "-p", direction.edge })
		if vim.v.shell_error == 0 and edge[1] == "0" then
			vim.fn.system({ "tmux", "select-pane", direction.pane })
			if vim.v.shell_error == 0 then
				return
			end
		end
	end
	vim.cmd("wincmd " .. direction.window)
end

---Register directional navigation across Neovim windows and adjacent tmux panes.
function M.setup()
	for _, direction in ipairs(directions) do
		vim.keymap.set("n", direction.key, function()
			navigate(direction)
		end, { desc = direction.desc })
	end
end

return M
