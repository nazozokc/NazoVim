local U = require("nazoplug.util")
local G = require("nazoplug.git")
local L = require("nazoplug.lock")
local I = require("nazoplug.install")

local M = {}

-- Default location of a legacy lazy.nvim pack directory.
function M.default_old_pack_dir()
	local data = vim.fn.stdpath("data")
	local old_pack_dir = U.join(data, "lazy")
	if U.is_dir(old_pack_dir) then
		return old_pack_dir
	end
	local legacy = U.join(vim.fn.fnamemodify(data, ":h"), "nvim/lazy")
	if U.is_dir(legacy) then
		return legacy
	end
	return nil
end

function M.uptodate(old_pack_dir)
	local marker = U.join(old_pack_dir, ".nazoplug-migrated")
	local mstat = vim.uv.fs_stat(marker)
	if not mstat then
		return false
	end
	local dstat = vim.uv.fs_stat(old_pack_dir)
	if not dstat then
		return false
	end
	if
		dstat.mtime.sec > mstat.mtime.sec
		or (dstat.mtime.sec == mstat.mtime.sec and dstat.mtime.nsec > mstat.mtime.nsec)
	then
		return false
	end
	return true
end

function M.mark(old_pack_dir)
	local marker = U.join(old_pack_dir, ".nazoplug-migrated")
	local ok, err = U.write_atomic(marker, "migrated\n")
	if not ok then
		U.warn("failed to write migration marker: " .. tostring(err))
	end
end

function M.migrate(specs, opts)
	opts = opts or {}
	local old_pack_dir = opts.old_pack_dir
	if old_pack_dir == nil then
		old_pack_dir = M.default_old_pack_dir()
	end
	local lock = {}
	if opts.lock_path then
		local existing, err = L.load(opts.lock_path)
		if existing then
			lock = existing
		elseif opts.strict then
			return nil, err
		end
	end
	local migrated = {}
	for _, spec in ipairs(specs) do
		if not U.exists(spec.dir) and old_pack_dir then
			local old_dir = U.join(old_pack_dir, spec.name)
			if G.is_repo(old_dir) then
				local made, mkdir_err = U.mkdir(U.dirname(spec.dir))
				if not made then
					return nil, string.format("failed to create %s: %s", U.dirname(spec.dir), tostring(mkdir_err))
				end
				local ok, created, link_err = pcall(vim.uv.fs_symlink, old_dir, spec.dir)
				if not ok or not created then
					local message = ok and link_err or created
					return nil, string.format("symlink failed for %s: %s", spec.name, tostring(message))
				end
				migrated[#migrated + 1] = spec.name
			end
		end
		if (opts.lock_path or opts.collect) and G.is_repo(spec.dir) then
			local entry, err = I.entry(spec)
			if entry then
				lock[spec.name] = entry
			elseif opts.strict then
				return nil, string.format("failed to read %s: %s", spec.name, err)
			end
		end
	end
	if opts.lock_path then
		local ok, err = L.save(opts.lock_path, lock)
		if not ok then
			return nil, err
		end
	end
	if old_pack_dir then
		M.mark(old_pack_dir)
	end
	return lock, migrated
end

return M
