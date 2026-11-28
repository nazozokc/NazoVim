local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h:h:h")
local init_path = root .. "/apps/nvim/init.lua"

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

local function truthy(value, label)
	if not value then
		error((label or "value") .. " is not truthy", 2)
	end
	return value
end

local function eq(actual, expected, label)
	if not vim.deep_equal(actual, expected) then
		error(string.format("%s: expected %s, got %s", label or "value", vim.inspect(expected), vim.inspect(actual)), 2)
	end
end

test("nvim init wires nazoplug options in a single table", function()
	local captured
	local saved = {
		nazoplug = package.loaded.nazoplug,
		options = package.loaded["config.options"],
		keymaps = package.loaded["config.keymaps"],
		autocmds = package.loaded["config.autocmds"],
		auto_install = vim.env.NAZOVIM_AUTO_INSTALL,
	}

	package.loaded.nazoplug = {
		setup = function(...)
			captured = { count = select("#", ...), opts = select(1, ...) }
			return true
		end,
	}
	package.loaded["config.options"] = {}
	package.loaded["config.keymaps"] = {}
	package.loaded["config.autocmds"] = {}
	vim.env.NAZOVIM_AUTO_INSTALL = "1"

	local chunk, load_err = loadfile(init_path)
	truthy(chunk, "loadfile " .. init_path .. ": " .. tostring(load_err))
	local ok, run_err = pcall(chunk)

	package.loaded.nazoplug = saved.nazoplug
	package.loaded["config.options"] = saved.options
	package.loaded["config.keymaps"] = saved.keymaps
	package.loaded["config.autocmds"] = saved.autocmds
	vim.env.NAZOVIM_AUTO_INSTALL = saved.auto_install

	truthy(ok, "init.lua: " .. tostring(run_err))
	eq(captured.count, 1, "setup argument count")
	local opts = captured.opts
	eq(opts.spec, "plugins", "opts.spec")
	eq(opts.defaults and opts.defaults.lazy, true, "opts.defaults.lazy")
	eq(opts.install and opts.install.missing, true, "opts.install.missing")
	truthy(opts.disabled_plugins and #opts.disabled_plugins > 0, "opts.disabled_plugins")
end)

io.write(string.format("\n%d passed, %d failed\n", passed, failed))
if failed > 0 then
	vim.cmd("cquit 1")
end
