local U = require("nazoplug.util")

local M = {}

local VERSION = 2
local uv = vim.uv or vim.loop

local function cache_path()
	return U.join(vim.fn.stdpath("cache"), "nazoplug", "spec-cache.lua")
end

local function bytecode_path()
	return U.join(vim.fn.stdpath("cache"), "nazoplug", "spec-cache.luac")
end

function M.path()
	return cache_path()
end

function M.bytecode_path()
	return bytecode_path()
end

local function dump_bytecode(chunk)
	local ok, bytecode = pcall(string.dump, chunk)
	if ok then
		return bytecode
	end
	return nil
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

local function encode(value, seen, depth)
	depth = depth or 0
	seen = seen or {}
	if depth > 40 then
		return nil, "table is too deep"
	end
	local kind = type(value)
	if kind == "nil" then
		return "nil"
	end
	if kind == "boolean" then
		return tostring(value)
	end
	if kind == "number" then
		if value ~= value or value == math.huge or value == -math.huge then
			return nil, "unsupported number"
		end
		return tostring(value)
	end
	if kind == "string" then
		return string.format("%q", value)
	end
	if kind == "function" then
		local upvalue = debug.getupvalue(value, 1)
		if upvalue ~= nil then
			return nil, "function has upvalues"
		end
		local ok, dumped = pcall(string.dump, value)
		if not ok then
			return nil, dumped
		end
		return "loadstring(" .. string.format("%q", dumped) .. ")"
	end
	if kind ~= "table" then
		return nil, "unsupported type: " .. kind
	end
	if seen[value] then
		return nil, "cyclic table"
	end
	seen[value] = true
	local keys = {}
	for key in pairs(value) do
		keys[#keys + 1] = key
	end
	table.sort(keys, function(left, right)
		local left_kind, right_kind = type(left), type(right)
		if left_kind == right_kind and (left_kind == "number" or left_kind == "string") then
			return left < right
		end
		return tostring(left) < tostring(right)
	end)
	local parts = {}
	for _, key in ipairs(keys) do
		local key_kind = type(key)
		if key_kind ~= "string" and key_kind ~= "number" then
			seen[value] = nil
			return nil, "unsupported table key"
		end
		local encoded_key = key_kind == "string" and string.format("%q", key) or tostring(key)
		local encoded_value, err = encode(value[key], seen, depth + 1)
		if not encoded_value then
			seen[value] = nil
			return nil, err
		end
		parts[#parts + 1] = "[" .. encoded_key .. "]=" .. encoded_value
	end
	seen[value] = nil
	return "{" .. table.concat(parts, ",") .. "}"
end

local function field(fields, name, value)
	local encoded, err = encode(value)
	if not encoded then
		return nil, name .. ": " .. tostring(err)
	end
	fields[#fields + 1] = string.format("[%q]=%s", name, encoded)
	return true
end

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
			return false
		end
	end
	return true
end

local function entry_code(spec)
	local source = spec._ and spec._.source
	if type(source) ~= "string" or source == "" then
		return nil, "spec has no source"
	end

	local fields = {}
	local function add(name, value)
		local ok, err = field(fields, name, value)
		if not ok then
			return nil, err
		end
		return true
	end

	for _, name in ipairs({
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
	}) do
		if spec[name] ~= nil then
			local ok, err = add(name, spec[name])
			if not ok then
				return nil, err
			end
		end
	end

	local has_config = type(spec.config) == "function"
	local needs_config = has_config
	local keys_ok = spec.keys == nil or cacheable(spec.keys)
	local build_ok = spec.build == nil or (type(spec.build) ~= "function" and cacheable(spec.build))
	if spec.keys ~= nil and keys_ok then
		local ok, err = add("keys", spec.keys)
		if not ok then
			return nil, err
		end
	end
	if spec.config == false then
		local ok, err = add("config", false)
		if not ok then
			return nil, err
		end
	elseif spec.opts ~= nil then
		local ok = add("opts", spec.opts)
		if not ok then
			needs_config = true
		end
	end
	local needs_hydrate = (spec.keys ~= nil and not keys_ok)
		or (spec.build ~= nil and not build_ok)
		or type(spec.init) == "function"
		or type(spec.enabled) == "function"
		or type(spec.cond) == "function"
	if type(spec.enabled) ~= "function" and spec.enabled ~= nil then
		local ok, err = add("enabled", spec.enabled)
		if not ok then
			return nil, err
		end
	end
	if type(spec.cond) ~= "function" and spec.cond ~= nil then
		local ok, err = add("cond", spec.cond)
		if not ok then
			return nil, err
		end
	end
	if spec.build ~= nil and build_ok then
		local ok, err = add("build", spec.build)
		if not ok then
			return nil, err
		end
	end

	local ok, err = add("source", source)
	if not ok then
		return nil, err
	end
	ok, err = add("dep", spec._.dep == true)
	if not ok then
		return nil, err
	end
	ok, err = add("top", spec._.top == true)
	if not ok then
		return nil, err
	end
	ok, err = add("explicit_lazy", spec._.explicit_lazy == true)
	if not ok then
		return nil, err
	end
	ok, err = add("explicit_priority", spec._.explicit_priority == true)
	if not ok then
		return nil, err
	end
	ok, err = add("explicit_enabled", spec._.explicit_enabled == true)
	if not ok then
		return nil, err
	end
	ok, err = add("has_config", has_config)
	if not ok then
		return nil, err
	end
	ok, err = add("needs_hydrate", needs_hydrate)
	if not ok then
		return nil, err
	end
	ok, err = add("needs_config", needs_config)
	if not ok then
		return nil, err
	end

	return "{" .. table.concat(fields, ",") .. "}"
end

local function encode_list(values)
	local encoded = {}
	for _, value in ipairs(values) do
		encoded[#encoded + 1] = string.format("%q", value)
	end
	return "{" .. table.concat(encoded, ",") .. "}"
end

function M.save(specs)
	local entries = {}
	for _, spec in ipairs(specs) do
		local code, err = entry_code(spec)
		if not code then
			return nil, err
		end
		entries[#entries + 1] = code
	end
	local fingerprint, sources, directories = manifest(specs)
	if not fingerprint then
		return nil, sources
	end
	local data = table.concat({
		"return {",
		"version=" .. tostring(VERSION) .. ",",
		"fingerprint=" .. string.format("%q", fingerprint) .. ",",
		"sources=" .. encode_list(sources) .. ",",
		"directories=" .. encode_list(directories) .. ",",
		"specs={",
		table.concat(entries, ",\n"),
		"},}",
	}, "\n")
	local written, err = U.write_atomic(cache_path(), data)
	if not written then
		return nil, err
	end
	local bytecode = dump_bytecode(loadstring(data))
	if bytecode then
		U.write_atomic(bytecode_path(), bytecode)
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

function M.load()
	local chunk, err = loadfile(bytecode_path())
	if not chunk then
		chunk, err = loadfile(cache_path())
		if chunk then
			local bytecode = dump_bytecode(chunk)
			if bytecode then
				U.write_atomic(bytecode_path(), bytecode)
			end
		end
	end
	if not chunk then
		return nil, err
	end
	local ok, cache = pcall(chunk)
	if not ok or type(cache) ~= "table" or cache.version ~= VERSION or type(cache.specs) ~= "table" then
		return nil
	end
	local fingerprint = verify(cache)
	if not fingerprint or cache.fingerprint ~= fingerprint then
		return nil
	end
	local specs, by_name = cache.specs, {}
	for _, spec in ipairs(specs) do
		if type(spec) ~= "table" or type(spec.name) ~= "string" or type(spec.source) ~= "string" then
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
		by_name[spec.name] = spec
	end

	if #specs == 0 then
		return nil
	end
	return specs, by_name, fingerprint
end

return M
