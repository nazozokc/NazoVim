local U = require("nazoplug.util")

local M = {}

-- Bump when the on-disk schema changes. Version 3 stores plain JSON: earlier
-- versions stored Lua source and executed it while loading, so anything able to
-- write the cache file could run code inside Neovim.
local VERSION = 3
local uv = vim.uv or vim.loop

local function cache_dir()
	return U.join(vim.fn.stdpath("cache"), "nazoplug")
end

local function cache_path()
	return U.join(cache_dir(), "spec-cache.json")
end

local function bytecode_path()
	return U.join(cache_dir(), "spec-cache.luac")
end

-- Cache files written by older versions are executable Lua chunks. They are
-- deleted instead of loaded, and re-created as JSON on the next save.
local function legacy_paths()
	return { U.join(cache_dir(), "spec-cache.lua"), bytecode_path() }
end

function M.path()
	return cache_path()
end

function M.bytecode_path()
	return bytecode_path()
end

function M.enabled(input, opts)
	if opts.cache == false then
		return false
	end
	return type(input) == "table" and input.import == "plugins" and input[1] == nil and next(input, "import") == nil
end

local function module_file(source)
	local relative = source:gsub("%.", "/")
	for _, candidate in ipairs({ "lua/" .. relative .. ".lua", "lua/" .. relative .. "/init.lua" }) do
		local found = vim.api.nvim_get_runtime_file(candidate, false)
		if #found > 0 then
			return vim.fn.fnamemodify(found[1], ":p")
		end
	end
	return nil
end

local function source_file(source)
	if source:sub(1, 1) == "/" or source:match("%.lua$") then
		return source
	end
	return module_file(source)
end

local function add_directory(directories, seen, path)
	if path and path ~= "" and path ~= "." and not seen[path] then
		seen[path] = true
		directories[#directories + 1] = path
	end
end

local function manifest(specs)
	local config = U.join(vim.fn.stdpath("config"), "lua")
	local sources, source_seen = {}, {}
	local directories, directory_seen = {}, {}
	local function add_source(path)
		if not path then
			return false
		end
		if not source_seen[path] then
			source_seen[path] = true
			sources[#sources + 1] = path
		end
		add_directory(directories, directory_seen, U.dirname(path))
		return true
	end

	for _, spec in ipairs(specs) do
		local source = source_file(spec._ and spec._.source)
		if not add_source(source) then
			return nil, "unable to resolve spec source: " .. tostring(spec._ and spec._.source)
		end
	end
	add_source(U.join(config, "plugins.lua"))
	add_directory(directories, directory_seen, U.join(config, "plugins"))
	add_directory(directories, directory_seen, config)
	table.sort(sources)
	table.sort(directories)

	local parts = {
		tostring(VERSION),
		string.format("%d.%d.%d", vim.version().major, vim.version().minor, vim.version().patch),
	}
	for _, path in ipairs(sources) do
		local stat = uv.fs_stat(path)
		if not stat then
			return nil, "missing spec source: " .. path
		end
		parts[#parts + 1] = string.format("%s|%d|%d|%d", path, stat.mtime.sec, stat.mtime.nsec, stat.size)
	end
	for _, path in ipairs(directories) do
		local stat = uv.fs_stat(path)
		if not stat then
			return nil, "missing spec directory: " .. path
		end
		parts[#parts + 1] = string.format("%s|%d|%d", path, stat.mtime.sec, stat.mtime.nsec)
	end
	return table.concat(parts, "\n"), sources, directories
end

function M.fingerprint(specs)
	return manifest(specs)
end

-- JSON only carries nil/boolean/number/string leaves, so anything else has to
-- be skipped and restored later by hydrating the original spec.
local function cacheable(value, seen)
	local kind = type(value)
	if kind ~= "table" then
		return kind == "nil" or kind == "boolean" or kind == "number" or kind == "string"
	end
	seen = seen or {}
	if seen[value] then
		return false
	end
	seen[value] = true
	for _, item in pairs(value) do
		if not cacheable(item, seen) then
			seen[value] = nil
			return false
		end
	end
	seen[value] = nil
	return true
end

local CACHED_FIELDS = {
	"name",
	"url",
	"dir",
	"branch",
	"submodules",
	"lazy",
	"priority",
	"cmd",
	"ft",
	"event",
	"dependencies",
	"main",
	"version",
	"commit",
	"tag",
	"pin",
}

local function entry_of(spec)
	local source = spec._ and spec._.source
	if type(source) ~= "string" or source == "" then
		return nil, "spec has no source"
	end

	local entry = { source = source }
	local function add(name, value)
		if not cacheable(value) then
			return false
		end
		entry[name] = value
		return true
	end

	for _, name in ipairs(CACHED_FIELDS) do
		if spec[name] ~= nil and not add(name, spec[name]) then
			return nil, name .. ": value is not cacheable"
		end
	end

	local has_config = type(spec.config) == "function"
	local needs_config = has_config
	local keys_ok = spec.keys == nil or cacheable(spec.keys)
	local build_ok = spec.build == nil or (type(spec.build) ~= "function" and cacheable(spec.build))
	if spec.keys ~= nil and keys_ok and not add("keys", spec.keys) then
		return nil, "keys: value is not cacheable"
	end
	if spec.config == false then
		if not add("config", false) then
			return nil, "config: value is not cacheable"
		end
	elseif spec.opts ~= nil then
		if not add("opts", spec.opts) then
			needs_config = true
		end
	end
	local needs_hydrate = (spec.keys ~= nil and not keys_ok)
		or (spec.build ~= nil and not build_ok)
		or type(spec.init) == "function"
		or type(spec.enabled) == "function"
		or type(spec.cond) == "function"
	if type(spec.enabled) ~= "function" and spec.enabled ~= nil and not add("enabled", spec.enabled) then
		return nil, "enabled: value is not cacheable"
	end
	if type(spec.cond) ~= "function" and spec.cond ~= nil and not add("cond", spec.cond) then
		return nil, "cond: value is not cacheable"
	end
	if spec.build ~= nil and build_ok and not add("build", spec.build) then
		return nil, "build: value is not cacheable"
	end

	entry.dep = spec._.dep == true
	entry.top = spec._.top == true
	entry.explicit_lazy = spec._.explicit_lazy == true
	entry.explicit_priority = spec._.explicit_priority == true
	entry.explicit_enabled = spec._.explicit_enabled == true
	entry.has_config = has_config
	entry.needs_hydrate = needs_hydrate
	entry.needs_config = needs_config
	return entry
end

function M.save(specs)
	local entries = {}
	for _, spec in ipairs(specs) do
		local entry, err = entry_of(spec)
		if not entry then
			return nil, err
		end
		entries[#entries + 1] = entry
	end
	local fingerprint, sources, directories = manifest(specs)
	if not fingerprint then
		return nil, sources
	end
	local cache = {
		version = VERSION,
		fingerprint = fingerprint,
		sources = sources,
		directories = directories,
		specs = entries,
	}
	local encoded_ok, data = pcall(vim.json.encode, cache)
	if not encoded_ok or type(data) ~= "string" then
		return nil, "cache is not encodable: " .. tostring(data)
	end
	-- JSON turns integer keys into strings and sparse arrays into nulls, so the
	-- cache is only written when it decodes back to exactly what was built.
	local decoded_ok, decoded = pcall(vim.json.decode, data)
	if not decoded_ok or not vim.deep_equal(decoded, cache) then
		return nil, "cache does not survive a JSON round trip"
	end
	local written, err = U.write_atomic(cache_path(), data, { mode = 384 })
	if not written then
		return nil, err
	end
	-- The directory is shared with other tools; keep it private as well.
	pcall(uv.fs_chmod, cache_dir(), 448)
	for _, path in ipairs(legacy_paths()) do
		uv.fs_unlink(path)
	end
	return true
end

local function verify(cache)
	if type(cache.sources) ~= "table" or type(cache.directories) ~= "table" then
		return nil
	end
	local parts = {
		tostring(VERSION),
		string.format("%d.%d.%d", vim.version().major, vim.version().minor, vim.version().patch),
	}
	for _, path in ipairs(cache.sources) do
		if type(path) ~= "string" then
			return nil
		end
		local stat = uv.fs_stat(path)
		if not stat then
			return nil
		end
		parts[#parts + 1] = string.format("%s|%d|%d|%d", path, stat.mtime.sec, stat.mtime.nsec, stat.size)
	end
	for _, path in ipairs(cache.directories) do
		if type(path) ~= "string" then
			return nil
		end
		local stat = uv.fs_stat(path)
		if not stat then
			return nil
		end
		parts[#parts + 1] = string.format("%s|%d|%d", path, stat.mtime.sec, stat.mtime.nsec)
	end
	return table.concat(parts, "\n")
end

-- Never execute cache files: they live in a shared cache directory and are not
-- authenticated. Decoding JSON is data-only, so a forged file can only cause a
-- cache miss.
function M.load()
	local data, read_err = U.read_file(cache_path())
	if not data then
		return nil, read_err
	end
	local ok, cache = pcall(vim.json.decode, data)
	if not ok or type(cache) ~= "table" or cache.version ~= VERSION or type(cache.specs) ~= "table" then
		return nil
	end
	local fingerprint = verify(cache)
	if not fingerprint or cache.fingerprint ~= fingerprint then
		return nil
	end
	local specs, by_name = {}, {}
	for _, spec in ipairs(cache.specs) do
		if
			type(spec) ~= "table"
			or type(spec.name) ~= "string"
			or spec.name == ""
			or type(spec.source) ~= "string"
			or by_name[spec.name] ~= nil
		then
			return nil
		end
		spec._ = {
			dep = spec.dep == true,
			top = spec.top == true,
			source = spec.source,
			installed = false,
			loaded = false,
			build = false,
			explicit_lazy = spec.explicit_lazy == true,
			explicit_priority = spec.explicit_priority == true,
			explicit_enabled = spec.explicit_enabled == true,
			needs_hydrate = spec.needs_hydrate == true,
			needs_config = spec.needs_config == true,
			has_config = spec.has_config == true,
			hydrated = false,
		}
		spec._.main = spec.main
		specs[#specs + 1] = spec
		by_name[spec.name] = spec
	end

	if #specs == 0 then
		return nil
	end
	return specs, by_name, fingerprint
end

return M
