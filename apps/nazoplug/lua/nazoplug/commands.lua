local U = require("nazoplug.util")
local L = require("nazoplug.lock")
-- Management operations are not needed until a command is invoked.
local G, I, S

local M = {}

local state = {}

local subcommands = {
	"sync",
	"install",
	"update",
	"check",
	"status",
	"build",
	"restore",
	"clean",
	"migrate",
}

local function notify(message, level)
	U.notify(message, level or vim.log.levels.INFO)
end

local function selected(names)
	local filtered = {}
	for _, name in ipairs(names) do
		if name:sub(1, 2) ~= "--" then
			filtered[#filtered + 1] = name
		end
	end
	if #filtered == 0 then
		return state.specs, nil
	end
	local result = {}
	for _, name in ipairs(filtered) do
		local spec = state.by_name[name]
		if not spec then
			return nil, "unknown plugin: " .. name
		end
		result[#result + 1] = spec
	end
	return result, nil
end

local function report(results, failed)
	local ok_count = 0
	for _, result in ipairs(results or {}) do
		if result.ok then
			ok_count = ok_count + 1
		else
			notify(string.format("%s: %s", result.name, result.err or "failed"), vim.log.levels.ERROR)
		end
	end
	if #(failed or {}) > 0 then
		notify(string.format("%d updated, %d failed", ok_count, #failed), vim.log.levels.WARN)
	else
		notify(string.format("%d plugin(s) updated", ok_count))
	end
end

local function run_install(specs, opts)
	opts = opts or {}
	local lock = state.lock
	local progress = require("nazoplug.ui").start_progress(opts.ui_title or "NazoPlug sync")
	local called, ok, results, failed, err = pcall(
		I.install,
		specs,
		lock,
		vim.tbl_extend("force", {
			lock_path = state.lock_path,
			save = true,
			by_name = state.by_name,
			concurrency = state.concurrency,
			on_progress = function(spec, phase, perr)
				progress.push(spec.name, phase, perr)
			end,
		}, opts)
	)
	if not called then
		-- Never leave the progress window and its timer behind on a crash.
		progress.close()
		notify("install crashed: " .. tostring(ok), vim.log.levels.ERROR)
		return false
	end
	progress.finish(#(results or {}) - #(failed or {}), #(failed or {}))
	if not ok and err then
		notify(err, vim.log.levels.ERROR)
	end
	report(results, failed)
	return ok
end

local function cmd_sync(args)
	local specs, err = selected(args)
	if not specs then
		notify(err, vim.log.levels.ERROR)
		return
	end
	return run_install(specs, { update = true, use_lock = true, offline = vim.tbl_contains(args, "--offline") })
end

local function has_missing(specs)
	local seen = {}
	local function visit(spec)
		if not spec or seen[spec.name] then
			return false
		end
		seen[spec.name] = true
		if not G.is_repo(spec.dir) then
			return true
		end
		for _, dependency_name in ipairs(spec.dependencies or {}) do
			if visit(state.by_name[dependency_name]) then
				return true
			end
		end
		return false
	end
	for _, spec in ipairs(specs) do
		if visit(spec) then
			return true
		end
	end
	return false
end

local function cmd_install(args)
	local specs, err = selected(args)
	if not specs then
		notify(err, vim.log.levels.ERROR)
		return
	end
	if not has_missing(specs) then
		notify("all plugins are installed")
		return true
	end
	return run_install(specs, { update = false, use_lock = "missing" })
end

local function cmd_update(args)
	local specs, err = selected(args)
	if not specs then
		notify(err, vim.log.levels.ERROR)
		return
	end
	local installed = {}
	for _, spec in ipairs(specs) do
		if G.is_repo(spec.dir) then
			installed[#installed + 1] = spec
		end
	end
	if #installed == 0 then
		notify("no installed plugins to update")
		return
	end
	return run_install(installed, { update = true, offline = vim.tbl_contains(args, "--offline") })
end

local function inspect()
	local lock = state.lock or {}
	local missing, mismatched = {}, {}
	local ok, disabled = 0, 0
	for _, spec in ipairs(state.specs or {}) do
		if not S.is_enabled(spec) then
			disabled = disabled + 1
		elseif not G.is_repo(spec.dir) then
			missing[#missing + 1] = spec.name
		else
			local current, err = I.check(spec, lock)
			if not current then
				mismatched[#mismatched + 1] = string.format("%s (%s)", spec.name, err)
			else
				ok = ok + 1
			end
		end
	end
	return missing, mismatched, ok, disabled
end

local function cmd_check()
	local missing, mismatched, ok, disabled = inspect()
	if #missing > 0 then
		notify("missing: " .. table.concat(missing, ", "), vim.log.levels.WARN)
	end
	if #mismatched > 0 then
		notify("mismatched: " .. table.concat(mismatched, ", "), vim.log.levels.WARN)
	end
	notify(string.format("%d ok, %d missing, %d mismatched, %d disabled", ok, #missing, #mismatched, disabled))
	return #missing == 0 and #mismatched == 0
end

local function cmd_status()
	local missing, mismatched, ok, disabled = inspect()
	local lock = state.lock or {}
	local lock_missing, stale = L.diff(lock, state.specs or {})
	notify(
		string.format(
			"%d plugin(s): %d ok, %d missing, %d mismatched, %d disabled",
			#(state.specs or {}),
			ok,
			#missing,
			#mismatched,
			disabled
		)
	)
	if #missing > 0 then
		notify("missing: " .. table.concat(missing, ", "), vim.log.levels.WARN)
	end
	if #mismatched > 0 then
		notify("mismatched: " .. table.concat(mismatched, ", "), vim.log.levels.WARN)
	end
	if #lock_missing > 0 then
		notify("no lock entry: " .. table.concat(lock_missing, ", "), vim.log.levels.WARN)
	end
	if #stale > 0 then
		notify("stale lock: " .. table.concat(stale, ", "), vim.log.levels.WARN)
	end
	return #missing == 0 and #mismatched == 0
end

local function cmd_build(args)
	local specs, err = selected(args)
	if not specs then
		notify(err, vim.log.levels.ERROR)
		return
	end
	local progress = require("nazoplug.ui").start_progress("NazoPlug build")
	local failed = 0
	for _, spec in ipairs(specs) do
		progress.push(spec.name, "start")
		local ok, build_err = I.build(spec, {})
		progress.push(spec.name, ok and "done" or "error", build_err)
		if not ok then
			failed = failed + 1
			notify(build_err, vim.log.levels.ERROR)
		end
	end
	progress.finish(#specs - failed, failed)
	notify(failed == 0 and "build complete" or string.format("%d build(s) failed", failed))
	return failed == 0
end

local function cmd_restore(args)
	local specs, err = selected(args)
	if not specs then
		notify(err, vim.log.levels.ERROR)
		return
	end
	local progress = require("nazoplug.ui").start_progress("NazoPlug restore")
	local failed = 0
	for _, spec in ipairs(specs) do
		local entry = state.lock[spec.name]
		if entry and entry.commit then
			if G.is_repo(spec.dir) then
				progress.push(spec.name, "start")
				local ok, restore_err = true, nil
				if not vim.tbl_contains(args, "--offline") then
					ok, restore_err = G.fetch(spec.dir, {})
					if not ok then
						ok = false
					end
				end
				local ok2, checkout_err = G.checkout(spec.dir, entry.commit, { submodules = spec.submodules })
				if ok and ok2 then
					progress.push(spec.name, "done")
				else
					local restore_message = restore_err or checkout_err
					progress.push(spec.name, "error", restore_message)
					failed = failed + 1
					notify(string.format("%s: %s", spec.name, restore_message), vim.log.levels.ERROR)
				end
			else
				progress.push(spec.name, "error", "not installed")
				failed = failed + 1
				notify(string.format("%s: not installed", spec.name), vim.log.levels.ERROR)
			end
		end
	end
	progress.finish(#specs - failed, failed)
	notify(failed == 0 and "restore complete" or string.format("%d restore(s) failed", failed))
	return failed == 0
end

local function cmd_clean(args)
	local lock = state.lock or {}
	local stale = {}
	local present = {}
	for _, spec in ipairs(state.specs) do
		present[spec.name] = true
	end
	for _, name in ipairs(L.names(lock)) do
		if not present[name] then
			stale[#stale + 1] = name
		end
	end
	local targets = {}
	if state.pack_dir then
		for _, name in ipairs(stale) do
			local dir = U.join(state.pack_dir, name)
			-- Names come from the (repo-controlled) lock file: never let one
			-- resolve outside the pack directory.
			if U.is_inside(state.pack_dir, dir) and U.exists(dir) then
				targets[name] = dir
			end
		end
		if U.is_dir(state.pack_dir) then
			for _, name in ipairs(vim.fn.readdir(state.pack_dir)) do
				if not name:find("/", 1, true) then
					local dir = U.join(state.pack_dir, name)
					if not present[name] and not lock[name] and U.is_dir(dir) then
						targets[name] = dir
					end
				end
			end
		end
	end
	local dirs = {}
	for _, dir in pairs(targets) do
		dirs[#dirs + 1] = dir
	end
	table.sort(dirs)
	if #dirs == 0 then
		notify("nothing to clean")
		return
	end
	local message = "Remove " .. #dirs .. " plugin(s)?\n" .. table.concat(dirs, "\n")
	if not vim.tbl_contains(args, "--yes") and not U.confirm(message) then
		notify("clean cancelled")
		return false
	end
	for _, dir in ipairs(dirs) do
		vim.fn.delete(dir, "rf")
	end
	for _, name in ipairs(stale) do
		L.remove(lock, name)
	end
	local ok, err = L.save(state.lock_path, lock)
	state.lock = lock
	if not ok then
		notify(err, vim.log.levels.ERROR)
	else
		notify(string.format("removed %d plugin(s)", #dirs))
	end
	return ok ~= nil
end

local function cmd_migrate()
	local MG = require("nazoplug.migrate")
	local lock, migrated = MG.migrate(state.specs, {
		lock_path = state.lock_path,
		strict = false,
	})
	if not lock then
		notify(migrated or "migration failed", vim.log.levels.ERROR)
		return
	end
	state.lock = lock
	notify(string.format("migrated %d plugin(s)", #(migrated or {})))
	return true
end

local handlers = {
	sync = cmd_sync,
	install = cmd_install,
	update = cmd_update,
	check = cmd_check,
	status = cmd_status,
	build = cmd_build,
	restore = cmd_restore,
	clean = cmd_clean,
	migrate = cmd_migrate,
}

function M.dispatch(args)
	G = G or require("nazoplug.git")
	I = I or require("nazoplug.install")
	S = S or require("nazoplug.spec_state")
	local command = args[1]
	if not command then
		return require("nazoplug.ui").browse(state)
	end
	local handler = handlers[command]
	if not handler then
		notify("unknown NazoPlug command: " .. command, vim.log.levels.ERROR)
		return
	end
	local rest = {}
	for index = 2, #args do
		rest[#rest + 1] = args[index]
	end
	return handler(rest)
end

local function complete(arglead, cmdline, _)
	local words = vim.split(cmdline, "%s+", { trimempty = true })
	local wants_names = #words >= 2
		and vim.tbl_contains(subcommands, words[2])
		and (cmdline:match("%s$") ~= nil or #words > 2)
	if not wants_names then
		return vim.tbl_filter(function(name)
			return name:sub(1, #arglead) == arglead
		end, subcommands)
	end
	local names = {}
	for name in pairs(state.by_name) do
		if name:sub(1, #arglead) == arglead then
			names[#names + 1] = name
		end
	end
	table.sort(names)
	return names
end

function M.setup(opts)
	state = opts or {}
	pcall(vim.api.nvim_del_user_command, "NazoPlug")
	vim.api.nvim_create_user_command("NazoPlug", function(args)
		M.dispatch(args.fargs)
	end, {
		nargs = "*",
		complete = complete,
		desc = "Manage NazoVim plugins",
	})
end

function M.state()
	return state
end

return M
