local U = require("nazoplug.util")
local G = require("nazoplug.git")
local L = require("nazoplug.lock")
local A = require("nazoplug.async")

local M = {}

local function as_commands(build)
	if type(build) == "function" or type(build) == "string" then
		return { build }
	end
	if type(build) == "table" and U.is_list(build) then
		return build
	end
	return { build }
end

local function source_plugin(spec)
	local loader = require("nazoplug.loader")
	loader.add_to_rtp(spec)
	loader.packadd(spec.dir)
	return true
end

function M.build(spec, opts)
	if spec.build == nil or spec.build == false then
		return true
	end
	if spec._.build then
		return true
	end
	opts = opts or {}
	for _, command in ipairs(as_commands(spec.build)) do
		if type(command) == "function" then
			local ok, err = pcall(command, spec)
			if not ok then
				return nil, string.format("build failed for %s: %s", spec.name, err)
			end
		elseif type(command) == "string" then
			local cmd = U.trim(command)
			if cmd:sub(1, 1) == ":" then
				local sourced, source_err = source_plugin(spec)
				if not sourced then
					return nil, string.format("build failed for %s: %s", spec.name, source_err)
				end
				local ok, err = pcall(vim.cmd, cmd:sub(2))
				if not ok then
					return nil, string.format("build failed for %s: %s", spec.name, err)
				end
			else
				local shell = vim.o.shell
				local result, err = A.system({ shell, "-c", cmd }, {
					cwd = spec.dir,
					text = true,
					timeout = opts.build_timeout or 300000,
				})
				if err or not result then
					return nil, string.format("build failed for %s: %s", spec.name, err or "process was aborted")
				end
				if result.code ~= 0 then
					local message = U.trim(result.stderr)
					if message == "" then
						message = U.trim(result.stdout)
					end
					if message == "" then
						message = string.format("exit code %d", result.code)
					end
					return nil, string.format("build failed for %s: %s", spec.name, message)
				end
			end
		else
			return nil, string.format("invalid build for %s", spec.name)
		end
	end
	spec._.build = true
	return true
end

function M.entry(spec)
	local head, err = G.head(spec.dir)
	if not head then
		return nil, err
	end
	local branch = G.current_branch(spec.dir)
	if not branch and not spec.tag and not spec.version and not spec.commit then
		branch = spec.branch or G.default_branch(spec.dir, spec.url)
	end
	local entry = { commit = head }
	if branch and branch ~= "" then
		entry.branch = branch
	end
	return entry
end

function M.ensure(spec, opts)
	opts = opts or {}
	if not spec._ then
		spec._ = {}
	end
	local installed = G.is_repo(spec.dir)
	local use_lock = spec.pin or opts.use_lock == true or (opts.use_lock == "missing" and not installed)
	local locked = use_lock and opts.lock and opts.lock[spec.name] or nil

	if installed and opts.update == false and not use_lock then
		spec._.installed = true
		local entry, entry_err = M.entry(spec)
		if not entry then
			return nil, string.format("failed to read HEAD for %s: %s", spec.name, entry_err)
		end
		local built, build_err = M.build(spec, opts)
		if not built then
			return entry, build_err
		end
		return entry, nil
	end

	if installed and locked and locked.commit then
		local head = G.head(spec.dir)
		local current_branch = G.current_branch(spec.dir)
		local branch_ok
		if spec.tag or spec.version or spec.commit then
			branch_ok = current_branch == nil
		else
			local expected_branch = spec.branch or locked.branch
			branch_ok = not expected_branch or current_branch == expected_branch
		end
		if head == locked.commit and branch_ok then
			spec._.installed = true
			local entry, entry_err = M.entry(spec)
			if not entry then
				return nil, string.format("failed to read HEAD for %s: %s", spec.name, entry_err)
			end
			local built, build_err = M.build(spec, opts)
			if not built then
				return entry, build_err
			end
			return entry, nil
		end
	end

	local locked_present = installed and locked and locked.commit and G.has_commit(spec.dir, locked.commit)

	if not installed then
		if U.exists(spec.dir) then
			local entries = vim.fn.readdir(spec.dir)
			if #entries > 0 then
				return nil, string.format("%s exists but is not a git repository", spec.dir)
			end
		end
		local clone_branch = nil
		if spec.branch and spec.version == nil and spec.commit == nil and spec.tag == nil then
			clone_branch = spec.branch
		end
		local ok, err = G.clone(spec, {
			branch = clone_branch,
			timeout = opts.timeout,
		})
		if not ok then
			return nil, string.format("clone failed for %s: %s", spec.name, err)
		end
		if locked and locked.commit and not G.has_commit(spec.dir, locked.commit) and not opts.offline then
			local fetched, fetch_err = G.fetch(spec.dir, { timeout = opts.timeout })
			if not fetched then
				return nil, string.format("fetch failed for %s: %s", spec.name, fetch_err)
			end
		end
	elseif not opts.offline and not locked_present and (opts.update ~= false or locked) then
		local ok, err = G.fetch(spec.dir, { timeout = opts.timeout })
		if not ok then
			return nil, string.format("fetch failed for %s: %s", spec.name, err)
		end
	end

	local checkout_branch = nil
	if not spec.tag and not spec.version and not spec.commit then
		checkout_branch = spec.branch or (locked and locked.branch)
	end
	local ok, err
	if locked and locked.commit then
		ok, err = G.checkout(spec.dir, locked.commit, {
			branch = checkout_branch,
			submodules = spec.submodules,
			timeout = opts.timeout,
		})
	else
		ok, err = G.checkout_spec(spec, {
			offline = opts.offline,
			branch = checkout_branch,
			timeout = opts.timeout,
		})
	end
	if not ok then
		return nil, string.format("checkout failed for %s: %s", spec.name, err)
	end

	spec._.installed = true
	local entry, entry_err = M.entry(spec)
	if not entry then
		return nil, string.format("failed to read HEAD for %s: %s", spec.name, entry_err)
	end
	spec._.build = false
	local built, build_err = M.build(spec, opts)
	if not built then
		return entry, build_err
	end
	return entry, nil
end

function M.prefetch(specs, opts)
	opts = opts or {}
	if opts.offline or opts.prefetch == false then
		return true, {}
	end
	local missing = {}
	for _, spec in ipairs(specs) do
		if spec.url and not U.exists(spec.dir) then
			missing[#missing + 1] = spec
		end
	end
	if #missing == 0 then
		return true, {}
	end
	local concurrency = opts.concurrency or 16
	local timeout = opts.timeout or 300000
	local index = 0
	local active = 0
	local done = false
	local aborted = false
	local errors = {}
	local processes = {}

	local function stop_processes(signal)
		local list = {}
		for process in pairs(processes) do
			list[#list + 1] = process
		end
		for _, process in ipairs(list) do
			pcall(function()
				process:kill(signal)
			end)
		end
	end

	local function wait_for_processes(ms)
		return vim.wait(ms, function()
			return next(processes) == nil
		end, 25)
	end

	local function pump()
		while active < concurrency and index < #missing do
			index = index + 1
			local spec = missing[index]
			local clone_branch = nil
			if spec.branch and spec.version == nil and spec.commit == nil and spec.tag == nil then
				clone_branch = spec.branch
			end
			local handle = {}
			local function finish(result)
				if handle.process then
					processes[handle.process] = nil
				end
				vim.schedule(function()
					active = active - 1
					if aborted then
						return
					end
					if result.code ~= 0 then
						errors[#errors + 1] =
							string.format("%s: %s", spec.name, U.trim(result.stderr or result.stdout or "clone failed"))
					end
					pump()
				end)
			end
			if opts.on_progress then
				opts.on_progress(spec, "prefetch")
			end
			local ok, process = pcall(vim.system, G.clone_command(spec, { branch = clone_branch }), {
				text = true,
				timeout = timeout,
			}, finish)
			if ok then
				handle.process = process
				processes[process] = true
				active = active + 1
			else
				errors[#errors + 1] = string.format("%s: %s", spec.name, tostring(process))
			end
		end
		if active == 0 and index >= #missing then
			done = true
		end
	end
	pump()
	if not done then
		local finished = vim.wait(timeout + 1000, function()
			return done
		end, 50)
		if not finished then
			aborted = true
			errors[#errors + 1] = "clone prefetch timed out"
			-- Never let a clone outlive the prefetch: the installer would race
			-- against it and could clone into the same directory.
			stop_processes("term")
			if not wait_for_processes(5000) then
				stop_processes("kill")
				wait_for_processes(1000)
			end
		end
	end
	return #errors == 0, errors
end

-- Detect a dependency cycle before concurrent installation: worker-based
-- visiting cannot rely on a serial DFS. Colors: nil = unvisited, 1 = in
-- progress, 2 = done.
local function detect_cycle(specs, by_name)
	local color = {}
	local stack = {}
	local function walk(spec)
		color[spec.name] = 1
		stack[#stack + 1] = spec.name
		for _, dependency_name in ipairs(spec.dependencies or {}) do
			local dependency = by_name[dependency_name]
			if dependency then
				if color[dependency.name] == 1 then
					local from = 1
					for index, name in ipairs(stack) do
						if name == dependency.name then
							from = index
							break
						end
					end
					local cycle = table.concat(vim.list_slice(stack, from), " -> ")
					return "dependency cycle: " .. cycle .. " -> " .. dependency.name
				end
				if color[dependency.name] == nil then
					local err = walk(dependency)
					if err then
						return err
					end
				end
			end
		end
		stack[#stack] = nil
		color[spec.name] = 2
		return nil
	end
	for _, spec in ipairs(specs) do
		if color[spec.name] == nil then
			local err = walk(spec)
			if err then
				return err
			end
		end
	end
	return nil
end

function M.install(specs, lock, opts)
	opts = opts or {}
	lock = lock or {}
	local by_name = {}
	if opts.by_name then
		for name, spec in pairs(opts.by_name) do
			by_name[name] = spec
		end
	end
	for _, spec in ipairs(specs) do
		by_name[spec.name] = spec
	end
	local results = {}
	local failed = {}

	local cycle_err = detect_cycle(specs, by_name)
	if cycle_err then
		return false, results, failed, cycle_err
	end

	M.prefetch(specs, opts)

	-- Per-plugin state for cross-worker dependency coordination.
	local states = {} -- name -> "running" | "done" | "failed"
	local recorded = {} -- name -> true (row already appended)
	local waiters = {} -- [co] = spec the worker is parked on

	local function record(spec, ok, err)
		if recorded[spec.name] then
			return
		end
		recorded[spec.name] = true
		results[#results + 1] = { name = spec.name, ok = ok, err = err }
		if not ok then
			failed[#failed + 1] = spec.name
		end
	end

	-- Wake workers parked on a dependency that has reached a terminal state.
	local function wake_waiters()
		local ready = {}
		for co, spec in pairs(waiters) do
			local state = states[spec.name]
			if state == "done" or state == "failed" then
				ready[#ready + 1] = co
			end
		end
		for _, co in ipairs(ready) do
			waiters[co] = nil
			A.resume(co)
		end
	end

	-- Ensure a spec and its dependency subtree. Runs inside a pool worker
	-- coroutine; parks (yields) while dependencies are being installed by
	-- other workers and at every subprocess boundary. Returns (ok, err, kind):
	-- kind == "skip" means the row is already recorded.
	local function stop_worker(spec, err)
		states[spec.name] = "failed"
		record(spec, false, err)
		wake_waiters()
		return false, err, "skip"
	end

	local function ensure_tree(spec, ctx)
		while true do
			if ctx and ctx.cancelled() then
				return stop_worker(spec, "cancelled")
			end
			local state = states[spec.name]
			if state == "done" then
				return true, nil, "skip"
			end
			if state == "failed" then
				return false, "dependency failed: " .. spec.name, "skip"
			end
			if state == "running" then
				waiters[coroutine.running()] = spec
				coroutine.yield()
			else
				break
			end
		end
		states[spec.name] = "running"

		for _, dependency_name in ipairs(spec.dependencies or {}) do
			local dependency = by_name[dependency_name]
			if dependency then
				ensure_tree(dependency, ctx)
				if states[dependency.name] == "failed" then
					return false, "dependency failed: " .. dependency.name, "skip"
				end
			end
		end

		if ctx and ctx.cancelled() then
			return stop_worker(spec, "cancelled")
		end
		if opts.on_progress then
			opts.on_progress(spec, "start")
		end
		local ensure_opts = vim.tbl_extend("force", {}, opts)
		ensure_opts.lock = lock
		local entry, err = M.ensure(spec, ensure_opts)
		if not entry then
			states[spec.name] = "failed"
			record(spec, false, err)
			if opts.on_progress then
				opts.on_progress(spec, "error", err)
			end
			wake_waiters()
			return false, err, "skip"
		end
		local set_ok, set_err = L.set(lock, spec.name, entry)
		if not set_ok then
			states[spec.name] = "failed"
			record(spec, false, set_err)
			wake_waiters()
			return false, set_err, "skip"
		end
		states[spec.name] = "done"
		local build_ok = err == nil
		record(spec, build_ok, err)
		if opts.on_progress then
			opts.on_progress(spec, build_ok and "done" or "build_error", err)
		end
		wake_waiters()
		return build_ok, err, "skip"
	end

	local pool = require("nazoplug.pool")
	local tasks = {}
	for _, spec in ipairs(specs) do
		tasks[#tasks + 1] = function(ctx)
			return ensure_tree(spec, ctx)
		end
	end
	pool.run(tasks, {
		concurrency = opts.concurrency or 8,
		stop_on_error = opts.stop_on_error,
		on_result = function(idx, ok, err, extra)
			local spec = specs[idx]
			if not spec then
				return
			end
			if states[spec.name] == "running" then
				-- worker crashed before recording its state
				states[spec.name] = ok and "done" or "failed"
			end
			wake_waiters()
			if extra == "skip" then
				-- rows and progress were handled inside the worker
				if not ok and not recorded[spec.name] and opts.on_progress then
					opts.on_progress(spec, "error", err)
				end
				return
			end
			-- unrecorded result (e.g. timed out): record it here
			if not recorded[spec.name] then
				record(spec, ok, err)
			end
			if not ok and opts.on_progress then
				opts.on_progress(spec, "error", err)
			end
		end,
	})

	if opts.lock_path and opts.save ~= false then
		local ok, err = L.save(opts.lock_path, lock)
		if not ok then
			return false, results, failed, err
		end
	end
	if #failed > 0 then
		return false, results, failed
	end
	return true, results, failed
end

function M.sync(specs, lock, opts)
	opts = vim.tbl_extend("force", { update = true, use_lock = true }, opts or {})
	return M.install(specs, lock, opts)
end

function M.install_missing(specs, lock, opts)
	opts = vim.tbl_extend("force", { update = false, use_lock = "missing" }, opts or {})
	local by_name = opts.by_name or {}
	local missing = {}
	local checked = {}
	local function needs_install(spec)
		if not spec or checked[spec.name] then
			return false
		end
		checked[spec.name] = true
		if not G.is_repo(spec.dir) then
			return true
		end
		for _, dependency_name in ipairs(spec.dependencies or {}) do
			if needs_install(by_name[dependency_name]) then
				return true
			end
		end
		return false
	end
	for _, spec in ipairs(specs) do
		if needs_install(spec) then
			missing[#missing + 1] = spec
		end
	end
	return M.install(missing, lock, opts)
end

function M.check(spec, lock)
	if not G.is_repo(spec.dir) then
		return false, "not installed"
	end
	local head, err = G.head(spec.dir)
	if not head then
		return false, err
	end
	local entry = lock and lock[spec.name]
	if entry and entry.commit and entry.commit ~= head then
		return false, "commit mismatch"
	end
	if not spec.tag and not spec.version and not spec.commit then
		local expected_branch = spec.branch or (entry and entry.branch)
		local current_branch = G.current_branch(spec.dir)
		if expected_branch and current_branch and current_branch ~= expected_branch then
			return false, "branch mismatch"
		end
	end
	return true, head
end

return M
