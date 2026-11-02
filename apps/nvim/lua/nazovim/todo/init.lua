local M = {}

local highlight = require("nazovim.todo.highlight")
local search = require("nazovim.todo.search")

M.matches = highlight.matches
M.search = search.search

---Highlight comments and expose project-search commands without plugin dependencies.
function M.setup()
	highlight.setup()
end

return M
