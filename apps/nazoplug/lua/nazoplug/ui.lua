-- Floating windows: live progress for long operations and a plugin browser.
--
-- Rendering runs on a uv timer so it keeps animating while the caller blocks
-- in vim.wait(); nvim.redraw is only issued when something changed.

local M = {}

local SPIN = { "◐", "◓", "◑", "◒" }

local ICONS = {
	pending = "○",
	done = "✓",
	fail = "✗",
}

local HL = {
	pending = "Comment",
	run = "DiagnosticInfo",
	done = "DiagnosticOk",
	fail = "DiagnosticError",
}

local function phase_icon(phase, tick)
	if phase == "start" or phase == "prefetch" then
		return SPIN[(tick % #SPIN) + 1], HL.run
	end
	if phase == "done" then
		return ICONS.done, HL.done
	end
	if phase == "error" or phase == "build_error" then
		return ICONS.fail, HL.fail
	end
	return ICONS.pending, HL.pending
end

local function phase_note(phase, err)
	if phase == "pending" then
		return "queued"
	end
	if phase == "prefetch" then
		return "cloning"
	end
	if phase == "start" then
		return "syncing"
	end
	if phase == "build_error" then
		return err and ("build: " .. err) or "build failed"
	end
	if phase == "error" then
		return err or "failed"
	end
	return ""
end

local function open_float(width, height, opts)
	opts = opts or {}
	-- Small terminals must not make the caller fail: clamp to the editor size.
	width = math.max(1, math.min(width, math.max(1, vim.o.columns - 2)))
	height = math.max(1, math.min(height, math.max(1, vim.o.lines - 2)))
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].modifiable = true
	local row = math.max(1, math.floor((vim.o.lines - height) / 2))
	local col = math.max(1, math.floor((vim.o.columns - width) / 2))
	local win = vim.api.nvim_open_win(buf, opts.enter == true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		zindex = 60,
	})
	return buf, win
end

local function clip(value, max)
	value = tostring(value or "")
	if #value > max then
		return value:sub(1, max - 1) .. "…"
	end
	return value
end

-- Live progress window. push() adds or updates a plugin row; finish() stops
-- the animation and schedules the window to close itself.
function M.start_progress(title)
	local width, height = 64, 14
	local created, buf, win = pcall(open_float, width, height)
	local timer = created and vim.uv.new_timer() or nil
	if not created or type(buf) ~= "number" or not timer then
		if created and type(buf) == "number" and win then
			pcall(vim.api.nvim_win_close, win, true)
		end
		-- No drawable UI (headless, tiny screen, failed timer): keep the API so
		-- the install path never leaks a half-open progress window.
		local noop = function() end
		return { push = noop, finish = noop, close = noop }
	end
	local started = vim.uv.hrtime()
	local rows = {} -- [name] = { name, phase, err }
	local order = {}
	local tick = 0
	local dirty = true
	local self = {}

	local function render()
		local done_count = 0
		for _, name in ipairs(order) do
			local phase = rows[name].phase
			if phase == "done" or phase == "error" or phase == "build_error" then
				done_count = done_count + 1
			end
		end
		local elapsed = (vim.uv.hrtime() - started) / 1e9
		local lines = { string.format(" %s  %d/%d  %4.1fs", title, done_count, #order, elapsed), "" }
		local highlights = { { "Title", 0, 0, -1 } }
		local count = 0
		for _, name in ipairs(order) do
			count = count + 1
			if count > height - 3 then
				break -- only the first N rows fit; remaining finish under notify()
			end
			local row = rows[name]
			local icon, hl = phase_icon(row.phase, tick)
			local text = string.format(" %s %s", icon, clip(name, 24))
			local note = phase_note(row.phase, row.err)
			if note ~= "" then
				local room = width - #text - 3
				if room > 0 then
					text = text .. "  " .. clip(note, room)
				end
			end
			lines[#lines + 1] = text
			highlights[#highlights + 1] = { hl, #lines - 1, 1, 2 }
		end
		vim.api.nvim_buf_clear_namespace(buf, -1, 0, -1)
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		for _, item in ipairs(highlights) do
			vim.api.nvim_buf_add_highlight(buf, -1, item[1], item[2], item[3], item[4])
		end
		vim.api.nvim_win_set_cursor(win, { #lines, 0 })
	end

	local scheduled = false
	local function frame()
		scheduled = false
		local animating = false
		for _, name in ipairs(order) do
			local phase = rows[name].phase
			if phase == "start" or phase == "prefetch" then
				animating = true
				break
			end
		end
		if dirty or animating then
			dirty = false
			pcall(render)
			pcall(vim.cmd.redraw)
		end
	end
	timer:start(0, 90, function()
		tick = tick + 1
		if scheduled then
			return
		end
		local animating = false
		for _, name in ipairs(order) do
			local phase = rows[name].phase
			if phase == "start" or phase == "prefetch" then
				animating = true
				break
			end
		end
		if dirty or animating then
			scheduled = true
			vim.schedule(frame)
		end
	end)

	function self.push(name, phase, err)
		local row = rows[name]
		if not row then
			row = { name = name, phase = "pending" }
			rows[name] = row
			order[#order + 1] = name
		end
		row.phase = phase
		row.err = err
		dirty = true
	end

	function self.close()
		pcall(function()
			timer:stop()
			timer:close()
		end)
		if win and vim.api.nvim_win_is_valid(win) then
			pcall(vim.api.nvim_win_close, win, true)
		end
		self.win = nil
		self.buf = nil
	end

	self.win = win
	self.buf = buf

	function self.finish(_ok_count, fail_count)
		vim.defer_fn(function()
			self.close()
		end, fail_count > 0 and 4000 or 1200)
	end

	vim.keymap.set("n", "q", self.close, { buffer = buf, silent = true })
	vim.keymap.set("n", "<Esc>", self.close, { buffer = buf, silent = true })

	return self
end

-- Plugin browser: `:NazoPlug` with no arguments. Lists plugins with their
-- state, branch and pinned commit; q closes, R refreshes, u updates and i
-- installs the plugin under the cursor.
function M.browse(plugins_state)
	local specs = plugins_state.specs or {}
	local by_name = plugins_state.by_name or {}
	local lock = plugins_state.lock or {}
	local width, height = 80, 20
	local created, buf, win = pcall(open_float, width, height, { enter = true })
	if not created or type(buf) ~= "number" then
		require("nazoplug.util").error("cannot open the plugin browser: " .. tostring(buf))
		return nil
	end

	local sorted = vim.deepcopy(specs)
	table.sort(sorted, function(a, b)
		return a.name < b.name
	end)

	local info = {} -- name -> { repo, branch, commit }

	local function render()
		local lines = { " NazoPlug  plugins: " .. #sorted .. "  (q close, R refresh, u update, i install)", "" }
		local highlights = { { "Title", 0, 0, -1 } }
		for _, spec in ipairs(sorted) do
			local entry = info[spec.name] or {}
			local icon, hl = ICONS.pending, HL.pending
			if entry.repo then
				icon, hl = ICONS.done, HL.done
			end
			local text = string.format(
				" %s %-28s %-10s %-9s %s",
				icon,
				clip(spec.name, 28),
				clip(entry.branch or "-", 10),
				clip(entry.commit or "-", 9),
				lock[spec.name] and "locked" or ""
			)
			lines[#lines + 1] = text
			highlights[#highlights + 1] = { hl, #lines - 1, 1, 2 }
		end
		vim.api.nvim_buf_clear_namespace(buf, -1, 0, -1)
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		for _, item in ipairs(highlights) do
			vim.api.nvim_buf_add_highlight(buf, -1, item[1], item[2], item[3], item[4])
		end
	end

	local function refresh()
		local refreshed, refresh_err = pcall(function()
			local pool = require("nazoplug.pool")
			local G = require("nazoplug.git")
			local tasks = {}
			for _, spec in ipairs(specs) do
				tasks[#tasks + 1] = function()
					local entry = { repo = G.is_repo(spec.dir) }
					if entry.repo then
						entry.branch = G.current_branch(spec.dir)
						entry.commit = G.head(spec.dir)
					end
					return true, nil, entry
				end
			end
			local results = pool.run(tasks, { concurrency = plugins_state.concurrency or 16 })
			for idx, result in ipairs(results) do
				local spec = specs[idx]
				if spec and result.extra then
					info[spec.name] = result.extra
					if result.extra.commit then
						result.extra.commit = result.extra.commit:sub(1, 7)
					end
				end
			end
			pcall(render)
			pcall(vim.cmd.redraw)
		end)
		if not refreshed then
			require("nazoplug.util").warn("browse refresh failed: " .. tostring(refresh_err))
		end
	end

	local function close()
		if win and vim.api.nvim_win_is_valid(win) then
			pcall(vim.api.nvim_win_close, win, true)
		end
	end

	local function plugin_at(line)
		local index = line - 2 -- header + blank
		local spec = sorted[index]
		if not spec then
			return nil
		end
		return spec.name, by_name[spec.name] or spec
	end

	local function act(command)
		local current_line = vim.api.nvim_win_get_cursor(win)[1]
		local name = plugin_at(current_line)
		if not name then
			return
		end
		require("nazoplug.commands").dispatch({ command, name })
		vim.schedule(refresh)
	end

	vim.keymap.set("n", "q", close, { buffer = buf, silent = true })
	vim.keymap.set("n", "<Esc>", close, { buffer = buf, silent = true })
	vim.keymap.set("n", "R", refresh, { buffer = buf, silent = true })
	vim.keymap.set("n", "u", function()
		act("update")
	end, { buffer = buf, silent = true })
	vim.keymap.set("n", "i", function()
		act("install")
	end, { buffer = buf, silent = true })

	refresh()
	return { buf = buf, win = win, close = close, refresh = refresh }
end

return M
