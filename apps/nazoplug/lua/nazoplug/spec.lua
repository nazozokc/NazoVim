local U = require("nazoplug.util")

local M = {}

local DEFAULT_LAZY = true
local DEFAULT_PRIORITY = 50

local function is_spec_table(value)
	return type(value) == "table"
		and (value[1] ~= nil or value.import ~= nil or value.url ~= nil or value.name ~= nil or value.dir ~= nil)
end

local function as_list(value)
	if value == nil then
		return {}
	end
	if type(value) == "table" and U.is_list(value) then
		local list = {}
		for index = 1, #value do
			list[index] = value[index]
		end
		return list
	end
	return { value }
end

local function validate_name(name)
	if type(name) ~= "string" or name == "" then
		return nil, "plugin name is empty"
	end
	if name == "." or name == ".." or name:find("/", 1, true) or name:find("\\", 1, true) then
		return nil, "invalid plugin name: " .. name
	end
	return true
end

local collect_any
local merge_specs

local function import_module(import, ctx)
	if type(import) == "function" then
		return import()
	end
	if type(import) ~= "string" then
		error("invalid import: " .. vim.inspect(import))
	end
	if ctx.imports[import] then
		return {}
	end
	ctx.imports[import] = true
	ctx.depth = ctx.depth + 1
	if ctx.depth > 20 then
		error("import depth exceeded at " .. import)
	end

	local roots = {}
	local seen = {}
	local rel = import:gsub("%.", "/")
	local rtp = ctx.rtp
	if not rtp then
		rtp = vim.opt.rtp:get()
		ctx.rtp = rtp
	end
	local has_init = false
	local has_module = false
	for _, root in ipairs(rtp) do
		local dir = U.join(root, "lua", rel)
		if not seen[dir] and U.is_dir(dir) then
			seen[dir] = true
			roots[#roots + 1] = dir
			if U.is_file(U.join(dir, "init.lua")) then
				has_init = true
			end
		end
		if U.is_file(U.join(root, "lua", rel .. ".lua")) then
			has_module = true
		end
	end

	if #roots == 0 or has_init or has_module then
		local ok, result = pcall(require, import)
		if ok then
			ctx.depth = ctx.depth - 1
			return result, import
		end
		local message = tostring(result)
		if not message:match("module '.-' not found") then
			ctx.depth = ctx.depth - 1
			error(string.format("failed to import %s: %s", import, message))
		end
	end

	local specs = {}
	for _, dir in ipairs(roots) do
		local files = U.list_files(dir, function(file_path)
			return file_path:match("%.lua$") ~= nil and file_path ~= U.join(dir, "init.lua")
		end)
		for _, file_path in ipairs(files) do
			local chunk, err = loadfile(file_path)
			if not chunk then
				error(string.format("failed to load %s: %s", file_path, err))
			end
			local ok, result = pcall(chunk)
			if not ok then
				error(string.format("failed to execute %s: %s", file_path, result))
			end
			local collected = collect_any(result, ctx, false, file_path)
			vim.list_extend(specs, collected)
		end
	end

	ctx.depth = ctx.depth - 1
	if #specs == 0 then
		if #roots == 0 then
			error("no specs found for import " .. import)
		end
		-- The group exists but holds no specs, which happens after every spec in
		-- it is replaced by a built-in feature. Treat it as empty.
		return {}
	end
	return specs
end

local function normalize(raw, ctx, is_dep, source)
	if type(raw) == "string" then
		raw = { raw }
	end
	if type(raw) ~= "table" then
		error("invalid plugin spec: " .. vim.inspect(raw))
	end
	if raw.import ~= nil then
		return collect_any(raw.import, ctx, is_dep, source)
	end

	local spec = {}
	for key, value in pairs(raw) do
		spec[key] = value
	end
	if type(raw.opts) == "table" then
		spec.opts = vim.deepcopy(raw.opts)
	end
	if type(raw.config) == "table" then
		spec.config = vim.deepcopy(raw.config)
	end
	local first = spec[1]
	spec[1] = nil

	if type(spec.config) == "table" then
		spec.opts = U.deep_merge(spec.opts or {}, spec.config)
		spec.config = nil
	end

	local name = spec.name
	if not name and type(first) == "string" then
		name = U.name_from_url(first)
	end
	if not name and type(spec.url) == "string" then
		name = U.name_from_url(spec.url)
	end
	if not name and type(spec.dir) == "string" then
		name = U.basename(U.expand(spec.dir))
	end
	local valid, name_err = validate_name(name)
	if not valid then
		error(name_err .. " in " .. vim.inspect(raw))
	end
	spec.name = name

	if spec.url == nil and type(first) == "string" then
		spec.url = U.url_from_short(first)
	end
	if spec.url == nil and type(spec.dir) ~= "string" then
		error("plugin " .. name .. " has neither url nor dir")
	end
	if spec.dir == nil then
		spec.dir = U.join(ctx.pack_dir, name)
	else
		spec.dir = U.expand(spec.dir)
	end

	spec.submodules = spec.submodules ~= false
	if spec.lazy == nil then
		spec.lazy = ctx.defaults.lazy == nil and DEFAULT_LAZY or ctx.defaults.lazy
	end
	spec.priority = spec.priority or ctx.defaults.priority or DEFAULT_PRIORITY
	if spec.enabled == nil then
		spec.enabled = true
	end

	if spec.cmd ~= nil then
		spec.cmd = as_list(spec.cmd)
	end
	if spec.ft ~= nil then
		spec.ft = as_list(spec.ft)
	end
	if spec.keys ~= nil then
		spec.keys = as_list(spec.keys)
	end
	if spec.event ~= nil then
		spec.event = as_list(spec.event)
	end

	spec._ = {
		raw = raw,
		dep = is_dep,
		top = not is_dep,
		source = source,
		installed = false,
		loaded = false,
		build = false,
		explicit_lazy = raw.lazy ~= nil,
		explicit_priority = raw.priority ~= nil,
		explicit_enabled = raw.enabled ~= nil,
	}

	local declared = as_list(spec.dependencies)
	spec.dependencies = {}

	-- Register before collecting dependencies: a dependency that points back to
	-- this spec must resolve to it instead of recursing forever. Cycles are
	-- reported later by the installer.
	local target = ctx.by_name[spec.name]
	if not target then
		target = spec
		ctx.by_name[spec.name] = spec
		ctx.list[#ctx.list + 1] = spec
	end
	for _, dependency in ipairs(declared) do
		local dependency_specs = collect_any(dependency, ctx, true, source)
		for _, dependency_spec in ipairs(dependency_specs) do
			U.extend_unique(spec.dependencies, { dependency_spec.name })
		end
	end
	if target ~= spec then
		merge_specs(target, spec)
		return target
	end

	spec._.modules = nil
	spec._.main = spec.main
	return spec
end

merge_specs = function(existing, incoming)
	existing._.dep = existing._.dep and incoming._.dep
	existing._.top = existing._.top or incoming._.top
	existing._.source = existing._.source or incoming._.source

	if incoming._.explicit_lazy or existing.lazy == nil then
		existing.lazy = incoming.lazy
	end
	if incoming._.explicit_priority or existing.priority == nil then
		existing.priority = incoming.priority
	end
	if incoming._.explicit_enabled then
		existing.enabled = incoming.enabled
	end
	for _, key in ipairs({
		"branch",
		"version",
		"commit",
		"tag",
		"pin",
		"cond",
		"build",
		"main",
		"url",
		"dir",
		"submodules",
	}) do
		if incoming[key] ~= nil then
			existing[key] = incoming[key]
		end
	end
	if incoming.opts ~= nil then
		existing.opts = U.deep_merge(existing.opts or {}, incoming.opts)
	end
	if incoming.config ~= nil then
		if existing.config == nil then
			existing.config = incoming.config
		elseif type(existing.config) == "function" and type(incoming.config) == "function" then
			local first, second = existing.config, incoming.config
			existing.config = function(plugin, opts)
				first(plugin, opts)
				second(plugin, opts)
			end
		else
			existing.config = incoming.config
		end
	end
	if incoming.init ~= nil then
		if existing.init == nil then
			existing.init = incoming.init
		elseif type(existing.init) == "function" and type(incoming.init) == "function" then
			local first, second = existing.init, incoming.init
			existing.init = function(plugin)
				first(plugin)
				second(plugin)
			end
		end
	end
	for _, key in ipairs({ "cmd", "ft", "keys", "event" }) do
		if incoming[key] ~= nil then
			existing[key] = existing[key] or {}
			vim.list_extend(existing[key], as_list(incoming[key]))
		end
	end
	existing.dependencies = existing.dependencies or {}
	U.extend_unique(existing.dependencies, incoming.dependencies or {})
	if incoming._.modules ~= nil then
		existing._.modules = incoming._.modules
	end
	if incoming.main ~= nil then
		existing._.main = incoming.main
	end
end

local function register_spec(spec, ctx)
	local existing = ctx.by_name[spec.name]
	if existing then
		if existing ~= spec then
			merge_specs(existing, spec)
		end
		return existing
	end
	ctx.by_name[spec.name] = spec
	ctx.list[#ctx.list + 1] = spec
	return spec
end

collect_any = function(value, ctx, is_dep, source)
	if value == nil then
		return {}
	end
	if type(value) == "function" then
		return collect_any(value(), ctx, is_dep, source)
	end
	if type(value) == "string" then
		if is_dep then
			local existing = ctx.by_name[U.name_from_url(value)]
			if existing then
				return { existing }
			end
		end
		local spec = normalize(value, ctx, is_dep, source)
		return spec and { register_spec(spec, ctx) } or {}
	end
	if type(value) ~= "table" then
		error("invalid plugin spec: " .. vim.inspect(value))
	end

	if value._ and value.name then
		local existing = ctx.by_name[value.name]
		if existing == value then
			return { value }
		end
		return { register_spec(value, ctx) }
	end

	if value.import ~= nil then
		local imported, import_source = import_module(value.import, ctx)
		local result = {}
		for _, item in ipairs(as_list(imported)) do
			vim.list_extend(result, collect_any(item, ctx, is_dep, import_source or source))
		end
		return result
	end

	if U.is_list(value) then
		local result = {}
		for _, item in ipairs(value) do
			vim.list_extend(result, collect_any(item, ctx, is_dep, source))
		end
		return result
	end

	if not is_spec_table(value) then
		error("invalid plugin spec: " .. vim.inspect(value))
	end

	local spec = normalize(value, ctx, is_dep, source)
	return { register_spec(spec, ctx) }
end

function M.collect(input, opts)
	opts = opts or {}
	local ctx = {
		list = {},
		by_name = {},
		imports = {},
		depth = 0,
		defaults = opts.defaults or {},
		pack_dir = opts.pack_dir,
	}
	local collected = collect_any(input, ctx, false, opts.source)
	for _, spec in ipairs(ctx.list) do
		spec._.top = not spec._.dep
	end
	return ctx.list, ctx.by_name, collected
end

function M.validate(spec)
	local errors, warnings = {}, {}
	if not spec.name or spec.name == "" then
		errors[#errors + 1] = "missing name"
	end
	if not spec.url and not spec.dir then
		errors[#errors + 1] = "missing url/dir"
	end
	if spec.commit and not spec.commit:match("^[0-9a-fA-F]+$") then
		errors[#errors + 1] = "invalid commit: " .. tostring(spec.commit)
	end
	if spec.version ~= nil and spec.branch ~= nil then
		warnings[#warnings + 1] = "both version and branch are set"
	end
	if spec.tag ~= nil and spec.version ~= nil then
		warnings[#warnings + 1] = "both tag and version are set"
	end
	if spec.tag ~= nil and (type(spec.tag) ~= "string" or spec.tag == "") then
		errors[#errors + 1] = "invalid tag: " .. tostring(spec.tag)
	end
	if spec.pin ~= nil and type(spec.pin) ~= "boolean" then
		errors[#errors + 1] = "invalid pin: " .. tostring(spec.pin)
	end
	if spec.cond ~= nil and type(spec.cond) ~= "boolean" and type(spec.cond) ~= "function" then
		errors[#errors + 1] = "invalid cond: " .. tostring(spec.cond)
	end
	if spec.enabled ~= nil and type(spec.enabled) ~= "boolean" and type(spec.enabled) ~= "function" then
		errors[#errors + 1] = "invalid enabled: " .. tostring(spec.enabled)
	end
	for _, cmd in ipairs(spec.cmd or {}) do
		if type(cmd) ~= "string" or cmd == "" then
			errors[#errors + 1] = "invalid cmd"
		elseif cmd:find("%s") then
			warnings[#warnings + 1] = "command name contains whitespace: " .. cmd
		end
	end
	for _, key in ipairs(spec.keys or {}) do
		local lhs = type(key) == "string" and key or (type(key) == "table" and key[1])
		if not lhs or lhs == "" then
			errors[#errors + 1] = "invalid key"
		end
	end
	return errors, warnings
end

return M
