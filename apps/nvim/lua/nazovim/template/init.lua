local M = {}

local expand = require("nazovim.template.lib.expand")
local insert = require("nazovim.template.lib.insert")
local project = require("nazovim.template.lib.project")
local store = require("nazovim.template.lib.store")

M.root = store.root
M.list = store.list
M.resolve = store.resolve
M.expand = expand.expand
M.insert = insert.insert
M.project = project.project

---Keep the template facade discoverable as a feature without extra work.
function M.setup() end

return M
