local M = {}

---Start the independently configurable built-in features.
function M.setup()
	require("nazovim.features").setup()
end

return M
