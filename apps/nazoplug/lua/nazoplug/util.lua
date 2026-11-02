local M = {}

local uv = vim.uv or vim.loop

function M.notify(msg, level, opts)
	level = level or vim.log.levels.INFO
	opts = opts or {}
	local fn = opts.once and vim.notify_once or vim.notify
	pcall(fn, msg, level, { title = opts.title or "nazoplug" })
end

function M.info(msg, opts)
	M.notify(msg, vim.log.levels.INFO, opts)
end

function M.warn(msg, opts)
	M.notify(msg, vim.log.levels.WARN, opts)
end

function M.error(msg, opts)
	M.notify(msg, vim.log.levels.ERROR, opts)
end

function M.is_list(value)
	if type(value) ~= "table" then
		return false
	end
	local count = 0
	for key in pairs(value) do
		if type(key) ~= "number" then
			return false
		end
		count = count + 1
	end
	for index = 1, count do
		if value[index] == nil then
			return false
		end
	end
	return true
end

function M.normname(name)
	if type(name) ~= "string" then
		return ""
	end
	return (name:lower():gsub("^n?vim%-", ""):gsub("%.n?vim$", ""):gsub("[%.%-]lua", ""):gsub("[^a-z]+", ""))
end

function M.trim(value)
	return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

function M.basename(path)
	path = path:gsub("/+$", "")
	return path:match("([^/]+)$") or path
end

function M.dirname(path)
	return path:match("^(.*)/[^/]+$") or "."
end

function M.join(...)
	local parts = { ... }
	for index, part in ipairs(parts) do
		if index == 1 then
			parts[index] = (part:gsub("/+$", ""))
		else
			parts[index] = (part:gsub("^/+", ""):gsub("/+$", ""))
		end
	end
	return table.concat(parts, "/")
end

function M.expand(path)
	if type(path) ~= "string" then
		return path
	end
	if path:sub(1, 1) == "~" then
		path = vim.fn.expand(path)
	end
	return vim.fn.fnamemodify(path, ":p"):gsub("/+$", "")
end

function M.exists(path)
	return uv.fs_stat(path) ~= nil
end

function M.is_dir(path)
	local stat = uv.fs_stat(path)
	return stat ~= nil and stat.type == "directory"
end

function M.is_file(path)
	local stat = uv.fs_stat(path)
	return stat ~= nil and stat.type == "file"
end

function M.mkdir(path)
	if path and path ~= "" then
		local ok, err = pcall(vim.fn.mkdir, path, "p")
		if not ok then
			return nil, err
		end
	end
	return true
end

-- True when path resolves to root or one of its descendants. Normalizing both
-- sides first means ".." segments cannot point outside root.
function M.is_inside(root, path)
	if type(root) ~= "string" or root == "" or type(path) ~= "string" or path == "" then
		return false
	end
	local base = vim.fs.normalize(root)
	local target = vim.fs.normalize(path)
	if target == base then
		return true
	end
	return target:sub(1, #base + 1) == base .. "/"
end

function M.read_file(path)
	local file, err = io.open(path, "rb")
	if not file then
		return nil, err
	end
	local data = file:read("*a")
	file:close()
	return data
end

function M.write_file(path, data)
	M.mkdir(M.dirname(path))
	local file, err = io.open(path, "wb")
	if not file then
		return nil, err
	end
	local ok, write_err = file:write(data)
	file:close()
	if not ok then
		return nil, write_err
	end
	return true
end

-- Replace path with data through a temporary file. opts.mode (octal) restricts
-- permissions before the rename so the file is never world-readable.
function M.write_atomic(path, data, opts)
	opts = opts or {}
	M.mkdir(M.dirname(path))
	local tmp = string.format("%s.tmp.%d.%d", path, uv.os_getpid(), math.random(1, 1000000))
	local ok, err = M.write_file(tmp, data)
	if not ok then
		return nil, err
	end
	if opts.mode then
		local chmodded, chmod_err = uv.fs_chmod(tmp, opts.mode)
		if not chmodded then
			uv.fs_unlink(tmp)
			return nil, chmod_err
		end
	end
	local renamed, rename_err = uv.fs_rename(tmp, path)
	if not renamed then
		uv.fs_unlink(tmp)
		return nil, rename_err
	end
	return true
end

function M.read_json(path)
	local data, err = M.read_file(path)
	if not data then
		return nil, err
	end
	local ok, value = pcall(vim.json.decode, data)
	if not ok then
		return nil, value
	end
	return value
end

function M.encode_json(value)
	local seen = {}
	local function encode(item)
		local kind = type(item)
		if item == vim.NIL or kind == "nil" then
			return "null"
		end
		if kind == "string" then
			return vim.json.encode(item)
		end
		if kind == "number" or kind == "boolean" then
			return tostring(item)
		end
		if kind ~= "table" then
			return vim.json.encode(item)
		end
		if seen[item] then
			error("cannot encode cyclic table")
		end
		seen[item] = true
		local parts = {}
		if M.is_list(item) and #item > 0 then
			for _, value_item in ipairs(item) do
				parts[#parts + 1] = encode(value_item)
			end
			seen[item] = nil
			return "[" .. table.concat(parts, ",") .. "]"
		end
		for _, key in ipairs(M.sorted_keys(item)) do
			parts[#parts + 1] = vim.json.encode(key) .. ":" .. encode(item[key])
		end
		seen[item] = nil
		return "{" .. table.concat(parts, ",") .. "}"
	end
	local ok, encoded = pcall(encode, value)
	if not ok then
		return nil, encoded
	end
	return encoded
end

function M.write_json(path, value)
	local encoded, err = M.encode_json(value)
	if not encoded then
		return nil, err
	end
	return M.write_atomic(path, encoded .. "\n")
end

function M.deep_merge(left, right)
	if type(left) ~= "table" or type(right) ~= "table" then
		return right
	end
	return vim.tbl_deep_extend("force", left, right)
end

function M.extend_unique(target, values)
	local seen = {}
	for _, value in ipairs(target) do
		seen[value] = true
	end
	for _, value in ipairs(values or {}) do
		if not seen[value] then
			target[#target + 1] = value
			seen[value] = true
		end
	end
	return target
end

function M.sorted_keys(value)
	local keys = vim.tbl_keys(value or {})
	table.sort(keys)
	return keys
end

function M.name_from_url(url)
	if type(url) ~= "string" then
		return nil
	end
	url = url:gsub("/+$", ""):gsub("%.git$", "")
	return url:match("([^/:]+)$")
end

function M.url_from_short(value)
	if type(value) ~= "string" then
		return nil
	end
	if value:match("^https?://") or value:match("^git@") or value:match("^ssh://") or value:match("^file://") then
		return value
	end
	if value:find("/", 1, true) then
		return "https://github.com/" .. value:gsub("%.git$", "") .. ".git"
	end
	return nil
end

function M.safe_call(fn, ...)
	local ok, result = xpcall(fn, debug.traceback, ...)
	if not ok then
		return false, result
	end
	return true, result
end

function M.list_files(root, predicate)
	local files = {}
	local function walk(dir)
		local ok, iterator = pcall(vim.fs.dir, dir)
		if not ok or not iterator then
			return
		end
		for name, kind in iterator do
			local path = M.join(dir, name)
			if kind == "directory" then
				walk(path)
			elseif kind == "file" or kind == "link" then
				if not predicate or predicate(path, name) then
					files[#files + 1] = path
				end
			elseif kind == nil then
				local stat = uv.fs_stat(path)
				if stat and stat.type == "directory" then
					walk(path)
				elseif stat and (stat.type == "file" or stat.type == "link") then
					if not predicate or predicate(path, name) then
						files[#files + 1] = path
					end
				end
			end
		end
	end
	walk(root)
	table.sort(files)
	return files
end

function M.confirm(message)
	if vim.fn.has("nvim") == 1 and vim.fn.confirm(message .. "\nContinue?", "&Yes\n&No", 2) == 1 then
		return true
	end
	return false
end

return M
