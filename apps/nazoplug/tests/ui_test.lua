local passed, failed = 0, 0

local function test(name, fn)
	local ok, err = xpcall(fn, debug.traceback)
	if ok then
		passed = passed + 1
		io.write("ok   " .. name .. "\n")
	else
		failed = failed + 1
		io.write("FAIL " .. name .. "\n" .. tostring(err) .. "\n")
	end
end

local function eq(actual, expected, label)
	if not vim.deep_equal(actual, expected) then
		error(string.format("%s: expected %s, got %s", label or "value", vim.inspect(expected), vim.inspect(actual)), 2)
	end
end

local function truthy(value, label)
	if not value then
		error((label or "value") .. " is not truthy", 2)
	end
	return value
end

local U = require("nazoplug.util")
local UI = require("nazoplug.ui")
local tmp = vim.fn.tempname()
vim.fn.mkdir(tmp, "p")
vim.env.XDG_DATA_HOME = U.join(tmp, "data")
vim.fn.mkdir(U.join(tmp, "data"), "p")

test("progress window opens, tracks rows and closes", function()
	local progress = UI.start_progress("Test sync")
	truthy(progress.win, "window handle")
	truthy(vim.api.nvim_win_is_valid(progress.win), "window valid")
	progress.push("alpha.nvim", "start")
	progress.push("beta.nvim", "pending")
	vim.wait(300, function()
		return false
	end, 20) -- let a timer tick render
	local buf = progress.buf
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	truthy(lines[1]:find("Test sync"), "header shows title: " .. lines[1])
	local joined = table.concat(lines, "\n")
	truthy(joined:find("alpha.nvim"), "alpha row present")
	truthy(joined:find("syncing"), "alpha is syncing")
	truthy(joined:find("beta.nvim"), "beta row present")
	truthy(joined:find("queued"), "beta is queued")
	progress.push("alpha.nvim", "done")
	vim.wait(300, function()
		return false
	end, 20)
	joined = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
	truthy(joined:find("1/2"), "header shows 1/2 (beta still queued): " .. joined)
	progress.close()
	truthy(progress.win == nil, "window closed")
end)

test("progress window shows errors and auto-closes on finish", function()
	local progress = UI.start_progress("Test errors")
	progress.push("gamma.nvim", "error", "clone failed: network down")
	vim.wait(300, function()
		return false
	end, 20)
	local joined = table.concat(vim.api.nvim_buf_get_lines(progress.buf, 0, -1, false), "\n")
	truthy(joined:find("clone failed: network down"), "error note shown")
	progress.finish(0, 1)
	local closed = vim.wait(6000, function()
		return progress.win == nil
	end, 50)
	truthy(closed, "window auto-closed after finish")
end)

test("browse window lists plugins with enrichment", function()
	local specs = {
		{ name = "zeta.nvim", dir = tmp .. "/pack/zeta.nvim" },
		{ name = "alpha.nvim", dir = tmp .. "/pack/alpha.nvim" },
	}
	local browse = UI.browse({
		specs = specs,
		by_name = { ["alpha.nvim"] = specs[2], ["zeta.nvim"] = specs[1] },
		lock = { ["alpha.nvim"] = { commit = "abc" } },
	})
	truthy(vim.api.nvim_win_is_valid(browse.win), "browse window valid")
	local lines = vim.api.nvim_buf_get_lines(browse.buf, 0, -1, false)
	truthy(lines[1]:find("plugins: 2"), "header count: " .. lines[1])
	-- sorted by name: alpha before zeta, after header + blank
	eq(lines[3]:find("alpha.nvim") ~= nil, true, "alpha row sorted first")
	eq(lines[4]:find("zeta.nvim") ~= nil, true, "zeta row sorted second")
	truthy(lines[3]:find("locked"), "alpha shows locked")
	browse.close()
	truthy(browse.win == nil or not vim.api.nvim_win_is_valid(browse.win), "browse window closed")
end)

test("progress degrades to a no-op without a drawable window", function()
	local original = vim.api.nvim_open_win
	vim.api.nvim_open_win = function()
		error("no ui")
	end
	local ok, err = pcall(function()
		local progress = UI.start_progress("No UI")
		eq(progress.win, nil)
		progress.push("alpha.nvim", "start")
		progress.finish(1, 0)
		progress.close()
	end)
	vim.api.nvim_open_win = original
	if not ok then
		error(err)
	end
end)

test("progress window fits a small editor", function()
	local columns, lines = vim.o.columns, vim.o.lines
	vim.o.columns = 30
	vim.o.lines = 10
	local ok, err = pcall(function()
		local progress = UI.start_progress("Small")
		truthy(progress.win, "window handle")
		local config = vim.api.nvim_win_get_config(progress.win)
		eq(config.width <= 28, true, "width clamped: " .. tostring(config.width))
		eq(config.height <= 8, true, "height clamped: " .. tostring(config.height))
		progress.close()
	end)
	vim.o.columns = columns
	vim.o.lines = lines
	if not ok then
		error(err)
	end
end)

test("browse reports instead of throwing when the window cannot open", function()
	local original = vim.api.nvim_open_win
	vim.api.nvim_open_win = function()
		error("no ui")
	end
	local ok, result = pcall(UI.browse, { specs = {}, by_name = {}, lock = {} })
	vim.api.nvim_open_win = original
	truthy(ok, "browse must not raise")
	eq(result, nil)
end)

io.write(string.format("\nui: %d passed, %d failed\n", passed, failed))
if failed > 0 then
	os.exit(1)
end
