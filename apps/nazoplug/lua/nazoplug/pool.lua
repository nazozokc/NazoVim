-- Bounded-concurrency task pool.
--
-- Tasks are functions that may park on subprocesses via async.system(). Each
-- task runs in its own coroutine; completed tasks deliver (ok, err, extra) to
-- per-index results. run() blocks until every task finishes.

local A = require("nazoplug.async")

local M = {}

-- tasks: array of functions returning (ok, err, extra)
-- opts:
--   concurrency (default 8)
--   stop_on_error: stop launching new tasks after a failure
--   timeout: global deadline in ms (default 3600000)
--   on_start(idx), on_result(idx, ok, err, extra): progress hooks
-- Returns results: array of { ok = bool, err = string?, extra = any }
function M.run(tasks, opts)
	opts = opts or {}
	local concurrency = math.max(1, opts.concurrency or 8)
	local results = {}
	local n_done = 0
	local cursor = 1
	local active = {}
	local stop = opts.stop_on_error == true
	local any_failed = false
	local cancelled = false

	local function count_active()
		local n = 0
		for _ in pairs(active) do
			n = n + 1
		end
		return n
	end

	local function finish(idx, ok, err, extra)
		if results[idx] then
			return
		end
		results[idx] = { ok = ok == true, err = err, extra = extra }
		n_done = n_done + 1
		if not ok then
			any_failed = true
		end
		if opts.on_result then
			pcall(opts.on_result, idx, results[idx].ok, err, extra)
		end
	end

	local function launch_next()
		while cursor <= #tasks and count_active() < concurrency and not (stop and any_failed) do
			local idx = cursor
			cursor = cursor + 1
			local co = coroutine.create(tasks[idx])
			active[co] = idx
			A.attach(co)
			A.on_complete(co, function(success, r1, r2, r3)
				active[co] = nil
				A.detach(co)
				if success then
					finish(idx, r1, r2, r3)
				else
					finish(idx, false, r1)
				end
			end)
			if opts.on_start then
				pcall(opts.on_start, idx)
			end
			local ctx = {
				index = idx,
				cancelled = function()
					return cancelled
				end,
			}
			local success, r1, r2, r3 = coroutine.resume(co, ctx)
			if coroutine.status(co) == "dead" then
				active[co] = nil
				A.detach(co)
				A.on_complete(co, nil)
				if success then
					finish(idx, r1, r2, r3)
				else
					finish(idx, false, r1)
				end
			end
		end
	end

	launch_next()
	if n_done < #tasks then
		local deadline = opts.timeout or 3600000
		local function sweep_cancelled()
			if not (stop and any_failed) then
				return false
			end
			while cursor <= #tasks do
				finish(cursor, false, "cancelled")
				cursor = cursor + 1
			end
			return true
		end
		local done = vim.wait(deadline, function()
			-- slots freed by finished workers let queued tasks start
			launch_next()
			if sweep_cancelled() then
				return true
			end
			return n_done >= #tasks
		end, 25)
		if not done then
			cancelled = true
			local list = {}
			for co in pairs(active) do
				list[#list + 1] = co
			end
			for _, co in ipairs(list) do
				A.abort(co)
			end
			vim.wait(2000, function()
				return n_done >= #tasks
			end, 25)
			for idx = 1, #tasks do
				if not results[idx] then
					finish(idx, false, "timed out")
				end
			end
		end
	end
	return results
end

return M
