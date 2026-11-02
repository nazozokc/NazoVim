local M = {}

local expand = require("nazovim.template.expand")
local insert = require("nazovim.template.insert")
local project = require("nazovim.template.project")
local store = require("nazovim.template.store")

M.root = store.root
M.list = store.list
M.resolve = store.resolve
M.expand = expand.expand
M.insert = insert.insert
M.project = project.project

return M
