local M = {}

---Locate the template tree, preferring user configuration and the installed config.
function M.root()
	local configured = vim.g.nazovim_template_dir
	if configured then
		return vim.fn.expand(configured)
	end
	local config = vim.fn.stdpath("config") .. "/template"
	if vim.fn.isdirectory(config) == 1 then
		return config
	end
	-- Repository fallback: lua/nazovim/template/store.lua -> repository root.
	local source = debug.getinfo(1, "S").source:sub(2)
	return vim.fs.normalize(vim.fs.dirname(source) .. "/../../../../../template")
end

---List available templates, either files or project directories.
function M.list(project)
	local base = M.root() .. (project and "/project" or "")
	local result = {}
	if vim.fn.isdirectory(base) == 0 then
		return result
	end
	for name, kind in vim.fs.dir(base, { depth = project and 1 or 5 }) do
		if (project and kind == "directory") or (not project and kind == "file" and not name:match("^project/")) then
			result[#result + 1] = name
		end
	end
	table.sort(result)
	return result
end

---Resolve a short template name, using the filetype to disambiguate when needed.
function M.resolve(name, project, ft)
	local choices = M.list(project)
	for _, item in ipairs(choices) do
		if item == name then
			return item
		end
	end
	local matches = {}
	for _, item in ipairs(choices) do
		if vim.fn.fnamemodify(item, ":t:r") == name then
			local item_ft = vim.filetype.match({ filename = item })
			if not ft or ft == "" or item_ft == ft then
				matches[#matches + 1] = item
			end
		end
	end
	if #matches == 1 then
		return matches[1]
	end
	error(#matches > 1 and "Ambiguous template: use its full relative path" or "Template not found: " .. name)
end

return M
