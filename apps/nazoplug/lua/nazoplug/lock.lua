local U = require("nazoplug.util")

local M = {}

local function normalize_entry(entry)
	if type(entry) ~= "table" then
		return nil, "lock entry must be a table"
	end
	local result = {}
	if entry.branch ~= nil and entry.branch ~= vim.NIL then
		if type(entry.branch) ~= "string" or entry.branch == "" then
			return nil, "invalid branch"
		end
		result.branch = entry.branch
	end
	if entry.commit ~= nil and entry.commit ~= vim.NIL then
		if type(entry.commit) ~= "string" or not entry.commit:match("^[0-9a-fA-F]+$") then
			return nil, "invalid commit"
		end
		result.commit = entry.commit
	end
	if result.commit == nil then
		return nil, "lock entry is missing commit"
	end
	return result
end

-- Lock names become path components under the pack directory, so they must not
-- be able to escape it: reject separators, parent references and flag-like
-- names (git would read a leading "-" as an option).
function M.valid_name(name)
	if type(name) ~= "string" or name == "" then
		return nil, "invalid lock name"
	end
	if name == "." or name == ".." then
		return nil, "invalid lock name: " .. name
	end
	if name:find("/", 1, true) or name:find("\\", 1, true) then
		return nil, "invalid lock name: " .. name
	end
	if name:find("\0", 1, true) then
		return nil, "invalid lock name: " .. name
	end
	if name:sub(1, 1) == "-" then
		return nil, "invalid lock name: " .. name
	end
	return true
end

local function sanitize(lock)
	if type(lock) ~= "table" then
		return nil, "lock must be a table"
	end
	local result = {}
	for name, entry in pairs(lock) do
		local valid, name_err = M.valid_name(name)
		if not valid then
			return nil, name_err
		end
		local normalized, err = normalize_entry(entry)
		if not normalized then
			return nil, string.format("%s: %s", name, err)
		end
		result[name] = normalized
	end
	return result
end

function M.load(path)
	if not U.exists(path) then
		return {}, nil
	end
	local lock, err = U.read_json(path)
	if not lock then
		return nil, err
	end
	local sanitized, sanitize_err = sanitize(lock)
	if not sanitized then
		return nil, string.format("%s: %s", path, sanitize_err)
	end
	return sanitized, nil
end

function M.save(path, lock)
	local sanitized, err = sanitize(lock)
	if not sanitized then
		return nil, err
	end
	local parent = U.dirname(path)
	if parent and parent ~= "" then
		local ok, mkdir_err = U.mkdir(parent)
		if not ok then
			return nil, mkdir_err
		end
	end
	local encoded, encode_err = U.encode_json(sanitized)
	if not encoded then
		return nil, encode_err
	end
	return U.write_atomic(path, encoded .. "\n")
end

function M.get(lock, name)
	local entry = lock[name]
	if not entry then
		return nil
	end
	return entry
end

function M.set(lock, name, entry)
	local normalized, err = normalize_entry(entry)
	if not normalized then
		return nil, err
	end
	lock[name] = normalized
	return true
end

function M.remove(lock, name)
	lock[name] = nil
end

function M.update_from_head(lock, name, head, branch)
	head = head and head:gsub("%s+$", "")
	if not head or not head:match("^[0-9a-fA-F]+$") then
		return nil, "invalid HEAD"
	end
	lock[name] = {
		branch = branch,
		commit = head,
	}
	return true
end

function M.diff(lock, specs)
	local present = {}
	for _, spec in ipairs(specs) do
		present[spec.name] = true
	end
	local missing, stale = {}, {}
	for _, spec in ipairs(specs) do
		if not lock[spec.name] then
			missing[#missing + 1] = spec.name
		end
	end
	for name in pairs(lock) do
		if not present[name] then
			stale[#stale + 1] = name
		end
	end
	table.sort(missing)
	table.sort(stale)
	return missing, stale
end

function M.ensure_runtime_copy(config_path, runtime_path)
	if U.exists(runtime_path) or not U.exists(config_path) then
		return runtime_path
	end
	local lock, err = M.load(config_path)
	if not lock then
		return nil, err
	end
	local ok, save_err = M.save(runtime_path, lock)
	if not ok then
		return nil, save_err
	end
	return runtime_path
end

function M.names(lock)
	local names = U.sorted_keys(lock)
	return names
end

-- Resolve the startup lock: locate the runtime lock, seed it from the config
-- lock (or a legacy lazy-lock.json), and load it.
function M.resolve_startup(opts)
	opts = opts or {}
	local data = vim.fn.stdpath("data")
	local config = vim.fn.stdpath("config")
	local lock_path = opts.lockfile or U.join(data, "nazoplug-lock.json")
	local config_lock = opts.config_lock or U.join(config, "nazoplug-lock.json")

	if not U.is_file(config_lock) then
		local legacy_config = U.join(config, "lazy-lock.json")
		if U.is_file(legacy_config) then
			config_lock = legacy_config
		end
	end
	if not U.is_file(lock_path) then
		local legacy_data = U.join(data, "lazy-lock.json")
		if not U.is_file(legacy_data) then
			local fallback = U.join(vim.fn.fnamemodify(data, ":h"), "nvim/lazy-lock.json")
			if U.is_file(fallback) then
				legacy_data = fallback
			end
		end
		if U.is_file(legacy_data) then
			local copied, err = M.ensure_runtime_copy(legacy_data, lock_path)
			if not copied then
				U.warn("failed to copy legacy lock: " .. tostring(err))
			end
		elseif U.is_file(config_lock) then
			local copied, err = M.ensure_runtime_copy(config_lock, lock_path)
			if not copied then
				U.warn("failed to copy config lock: " .. tostring(err))
			end
		end
	end

	local lock, err = M.load(lock_path)
	if not lock then
		U.error("failed to load lock: " .. tostring(err))
		lock = {}
	end
	return lock_path, config_lock, lock
end

function M.count(lock)
	local count = 0
	for _ in pairs(lock) do
		count = count + 1
	end
	return count
end

return M
