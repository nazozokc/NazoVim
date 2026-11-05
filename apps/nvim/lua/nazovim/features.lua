local M = {}

---Features that do not start with the initial pass.
---Every other feature file is loaded during `setup()`.
local phases = {
	statusline = "VimEnter",
	search = "VimEnter",
	colors = "VimEnter",
	todo = "VimEnter",
	["lsp.references"] = "VimEnter",
	["ui.scrollbar"] = "VimEnter",
	["ui.modes"] = "VimEnter",
	["ui.filename"] = "VimEnter",
	["ui.notifications"] = "AfterPlugins",
	["cmdline.peek"] = "CmdlineEnter",
	["startup.quickstart"] = "AfterPlugins",
}

local scanned = nil

---Return every feature as `{ name, phase }`.
---A feature is any Lua file below `lua/nazovim/`, except files in a `lib/`
---directory. `foo/init.lua` becomes `foo`; `foo/bar.lua` becomes `foo.bar`.
local function features()
	if scanned then
		return scanned
	end

	local result = {}
	local source = debug.getinfo(1, "S").source:sub(2)
	local root = vim.fs.dirname(vim.fn.fnamemodify(source, ":p"))

	local function walk(directory, prefix)
		for name, kind in vim.fs.dir(directory) do
			if kind == "directory" then
				if name ~= "lib" and name:sub(1, 1) ~= "." then
					walk(directory .. "/" .. name, prefix .. name .. ".")
				end
			elseif kind == "file" and name:sub(-4) == ".lua" and name ~= "features.lua" then
				local base = name:sub(1, -5)
				if base ~= "init" then
					result[#result + 1] = prefix .. base
				elseif prefix ~= "" then
					result[#result + 1] = prefix:sub(1, -2)
				end
			end
		end
	end

	walk(root, "")
	table.sort(result)

	scanned = {}
	for _, name in ipairs(result) do
		scanned[#scanned + 1] = { name = name, phase = phases[name] or "start" }
	end
	return scanned
end

local function is_disabled(disabled, name)
	if type(disabled) ~= "table" then
		return false
	end
	if disabled[name] == true then
		return true
	end
	for _, disabled_name in ipairs(disabled) do
		if disabled_name == name then
			return true
		end
	end
	return false
end

---Return whether a registered feature is enabled by user configuration.
function M.enabled(name)
	return not is_disabled(vim.g.nazovim_disabled_features, name)
end

local function setup_phase(phase, disabled, context)
	for _, feature in ipairs(features()) do
		if feature.phase == phase and not is_disabled(disabled, feature.name) then
			local module = require("nazovim." .. feature.name)
			assert(type(module.setup) == "function", "NazoVim feature lacks setup(): " .. feature.name)
			module.setup(context)
		end
	end
end

---Return the names of independently configurable built-in features.
function M.available()
	local names = {}
	for _, feature in ipairs(features()) do
		names[#names + 1] = feature.name
	end
	return names
end

---Start built-in features unless their names are listed in `vim.g.nazovim_disabled_features`.
function M.setup()
	local disabled = vim.g.nazovim_disabled_features
	setup_phase("start", disabled)
	local group = vim.api.nvim_create_augroup("NazoVimFeatures", { clear = true })
	local has_cmdline, has_vimenter = false, false
	for _, feature in ipairs(features()) do
		if not is_disabled(disabled, feature.name) then
			has_cmdline = has_cmdline or feature.phase == "CmdlineEnter"
			has_vimenter = has_vimenter or feature.phase == "VimEnter"
		end
	end
	if has_cmdline then
		vim.api.nvim_create_autocmd("CmdlineEnter", {
			group = group,
			pattern = ":",
			once = true,
			callback = function()
				setup_phase("CmdlineEnter", disabled)
			end,
		})
	end
	if has_vimenter then
		vim.api.nvim_create_autocmd("VimEnter", {
			group = group,
			once = true,
			callback = function()
				vim.schedule(function()
					setup_phase("VimEnter", disabled)
				end)
			end,
		})
	end
end

---Start features that require the initialized plugin manager.
function M.setup_after_plugins(manager)
	setup_phase("AfterPlugins", vim.g.nazovim_disabled_features, manager)
end

return M
