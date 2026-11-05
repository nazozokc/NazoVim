local expand = require("nazovim.template.lib.expand")
local store = require("nazovim.template.lib.store")

local M = {}

---Generate a project into a new directory; refuse any existing destination.
function M.project(name, destination)
	local selected = store.resolve(name, true)
	local source = store.root() .. "/project/" .. selected
	local target = vim.fs.normalize(vim.fn.fnamemodify(destination, ":p")):gsub("/$", "")
	if vim.uv.fs_lstat(target) then
		error("Project destination already exists: " .. target)
	end
	-- Read and validate everything before creating any files.
	local files = {}
	for path, kind in vim.fs.dir(source, { depth = 20 }) do
		if kind == "link" then
			error("Project templates cannot contain symbolic links: " .. path)
		end
		if kind == "file" then
			files[#files + 1] = { path = path, lines = expand.expand(vim.fn.readfile(source .. "/" .. path), path) }
		end
	end
	if #files == 0 then
		error("Project template is empty")
	end
	vim.fn.mkdir(target, "p")
	for _, file in ipairs(files) do
		local path = target .. "/" .. file.path
		vim.fn.mkdir(vim.fs.dirname(path), "p")
		if vim.fn.writefile(file.lines, path) ~= 0 then
			error("Could not write template: " .. path)
		end
	end
	vim.notify("Created project: " .. target)
end

return M
