local M = {}

---Start the built-in editor features.
function M.setup()
	-- Commands are cheap to register; their implementations load on first use.
	require("nazovim.commands").setup()

	-- Editor primitives: mappings and buffer-local hooks.
	require("nazovim.pairs").setup()
	require("nazovim.surround").setup()
	require("nazovim.dial").setup()
	require("nazovim.motion").setup()
	require("nazovim.marks").setup()
	require("nazovim.spell").setup()
	require("nazovim.folding").setup()
	require("nazovim.indent").setup()
	require("nazovim.tabline").setup()
	require("nazovim.whichkey").setup()

	-- Diagnostics/progress must be ready before the first LspAttach/notification.
	require("nazovim.diagnostics").setup()
	require("nazovim.progress").setup()

	vim.keymap.set("n", "<Plug>(jumpcursor-jump)", function()
		require("nazovim.jump").jump()
	end, { silent = true })

	-- The command-line preview only matters once the user opens ":".
	vim.api.nvim_create_autocmd("CmdlineEnter", {
		pattern = ":",
		once = true,
		callback = function()
			require("nazovim.peek").setup()
		end,
	})

	-- Decorations can wait until the first screen has been drawn.
	vim.api.nvim_create_autocmd("VimEnter", {
		once = true,
		callback = function()
			vim.schedule(function()
				require("nazovim.statusline").setup()
				require("nazovim.search").setup()
				require("nazovim.colors").setup()
				require("nazovim.todo").setup()
				require("nazovim.references").setup()
				require("nazovim.scrollbar").setup()
				require("nazovim.modes").setup()
				require("nazovim.filename").setup()
			end)
		end,
	})
end

return M
