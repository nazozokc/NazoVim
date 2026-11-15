local U = require("nazoplug.util")
local L = require("nazoplug.lock")

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

local tmp = vim.fn.tempname()
vim.fn.mkdir(tmp, "p")
vim.fn.mkdir(U.join(tmp, "data"), "p")
vim.fn.mkdir(U.join(tmp, "config"), "p")
vim.env.XDG_DATA_HOME = U.join(tmp, "data")
vim.env.XDG_CONFIG_HOME = U.join(tmp, "config")

local config_lock = U.join(tmp, "config-lock.json")
local runtime_lock = U.join(tmp, "data/nazoplug-lock.json")
U.write_file(
	config_lock,
	'{\n\t"flash.nvim": {\n\t\t"branch": "main",\n\t\t"commit": "fcea7ff883235d9024dc41e638f164a450c14ca2"\n\t}\n}\n'
)

test("empty runtime lock is reseeded from the config lock", function()
	U.write_file(runtime_lock, "{}\n")
	local path, _, lock = L.resolve_startup({ lockfile = runtime_lock, config_lock = config_lock })
	eq(path, runtime_lock)
	eq(lock["flash.nvim"].commit, "fcea7ff883235d9024dc41e638f164a450c14ca2")
	eq(U.read_json(runtime_lock)["flash.nvim"].branch, "main")
end)

test("non-empty runtime lock is left untouched", function()
	U.write_file(runtime_lock, '{\n\t"flash.nvim": {\n\t\t"branch": "main",\n\t\t"commit": "0123456"\n\t}\n}\n')
	local _, _, lock = L.resolve_startup({ lockfile = runtime_lock, config_lock = config_lock })
	eq(lock["flash.nvim"].commit, "0123456")
end)

test("invalid runtime lock is not overwritten", function()
	U.write_file(runtime_lock, "{invalid\n")
	local _, _, lock = L.resolve_startup({ lockfile = runtime_lock, config_lock = config_lock })
	eq(lock, {})
	eq(U.read_file(runtime_lock), "{invalid\n")
end)

vim.fn.delete(tmp, "rf")

io.write(string.format("\n%d passed, %d failed\n", passed, failed))
if failed > 0 then
	vim.cmd("cquit 1")
else
	vim.cmd("qall!")
end
