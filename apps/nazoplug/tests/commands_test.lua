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

local C = require("nazoplug.commands")
local H = require("nazoplug.health")
local S = require("nazoplug.spec")
local G = require("nazoplug.git")
local U = require("nazoplug.util")
local tmp = vim.fn.tempname()
vim.fn.mkdir(tmp, "p")
vim.env.XDG_DATA_HOME = U.join(tmp, "data")
vim.fn.mkdir(U.join(tmp, "data"), "p")

local origin = U.join(tmp, "origin")
vim.fn.mkdir(origin, "p")
G.run({ "init", "-b", "main" }, { cwd = origin })
G.run({ "config", "user.email", "test@example.com" }, { cwd = origin })
G.run({ "config", "user.name", "Test" }, { cwd = origin })
vim.fn.writefile({ "test" }, U.join(origin, "file.txt"))
G.run({ "add", "." }, { cwd = origin })
G.run({ "commit", "-m", "one" }, { cwd = origin })

test("commands registers NazoPlug and handles empty state", function()
	C.setup({
		specs = {},
		by_name = {},
		lock = {},
		lock_path = tmp .. "/lock.json",
		pack_dir = tmp .. "/pack",
	})
	eq(vim.fn.exists(":NazoPlug"), 2)
	eq(C.dispatch({ "check" }), true)
	eq(C.dispatch({ "status" }), true)
	C.dispatch({ "install" })
	C.dispatch({ "update" })
	C.dispatch({ "build" })
	C.dispatch({ "restore" })
	C.dispatch({ "clean" })
	C.dispatch({ "migrate" })
	C.dispatch({ "bogus" })
	C.dispatch({})
end)

test("commands install selected plugin with its dependencies", function()
	local pack_dir = U.join(tmp, "command-pack")
	local input = {
		{
			name = "command-parent.nvim",
			url = origin,
			dependencies = { { url = origin, name = "command-child.nvim" } },
		},
	}
	local specs, by_name = S.collect(input, { pack_dir = pack_dir })
	C.setup({
		specs = specs,
		by_name = by_name,
		lock = {},
		lock_path = U.join(tmp, "command-lock.json"),
		pack_dir = pack_dir,
	})
	eq(C.dispatch({ "install", "command-parent.nvim" }), true)
	truthy(U.is_dir(by_name["command-parent.nvim"].dir))
	truthy(U.is_dir(by_name["command-child.nvim"].dir))

	vim.fn.delete(by_name["command-child.nvim"].dir, "rf")
	eq(C.dispatch({ "install", "command-parent.nvim" }), true)
	truthy(U.is_dir(by_name["command-child.nvim"].dir))
end)

test("commands clean removes orphan directories", function()
	local pack_dir = U.join(tmp, "clean-pack")
	local orphan = U.join(pack_dir, "orphan.nvim")
	truthy(U.mkdir(orphan))
	C.setup({
		specs = {},
		by_name = {},
		lock = {},
		lock_path = U.join(tmp, "clean-lock.json"),
		pack_dir = pack_dir,
	})
	eq(C.dispatch({ "clean", "--yes" }), true)
	eq(U.exists(orphan), false)
end)

test("commands clean ignores lock names outside the pack directory", function()
	local pack_dir = U.join(tmp, "clean-escape-pack")
	local outside = U.join(tmp, "clean-escape-outside")
	truthy(U.mkdir(pack_dir))
	truthy(U.mkdir(outside))
	truthy(U.write_file(U.join(outside, "keep.txt"), "keep\n"))
	C.setup({
		specs = {},
		by_name = {},
		lock = { ["../clean-escape-outside"] = { commit = string.rep("a", 40) } },
		lock_path = U.join(tmp, "clean-escape-lock.json"),
		pack_dir = pack_dir,
	})
	C.dispatch({ "clean", "--yes" })
	eq(U.exists(U.join(outside, "keep.txt")), true)
end)

test("install crash closes the progress window", function()
	local pack_dir = U.join(tmp, "crash-pack")
	local specs, by_name = S.collect({ { name = "crash.nvim", url = origin } }, { pack_dir = pack_dir })
	C.setup({
		specs = specs,
		by_name = by_name,
		lock = {},
		lock_path = U.join(tmp, "crash-lock.json"),
		pack_dir = pack_dir,
	})
	local I = require("nazoplug.install")
	local original = I.install
	I.install = function()
		error("boom")
	end
	local wins_before = #vim.api.nvim_list_wins()
	local ok, result, err = pcall(C.dispatch, { "install" })
	I.install = original
	truthy(ok, "dispatch must not raise: " .. tostring(result))
	eq(result, false)
	eq(#vim.api.nvim_list_wins(), wins_before, "progress window must be closed")
	eq(err, nil)
end)

test("lock rejects names that could escape the pack directory", function()
	local L = require("nazoplug.lock")
	for _, name in ipairs({ "", ".", "..", "a/b", "a\\b", "-rf" }) do
		eq(L.valid_name(name), nil, "name " .. vim.inspect(name))
	end
	truthy(L.valid_name("plugin.nvim"))
	local path = U.join(tmp, "traversal-lock.json")
	truthy(U.write_file(path, '{"../evil":{"commit":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}}'))
	local lock, err = L.load(path)
	eq(lock, nil)
	truthy(err and err:find("invalid lock name", 1, true))
end)

test("commands migrate refreshes the in-memory lock", function()
	local lock_path = U.join(tmp, "migrate-state-lock.json")
	local commit = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
	truthy(U.write_file(lock_path, string.format('{"migrated.nvim":{"commit":"%s"}}\n', commit)))
	C.setup({
		specs = {},
		by_name = {},
		lock = {},
		lock_path = lock_path,
		pack_dir = U.join(tmp, "migrate-state-pack"),
	})
	eq(C.dispatch({ "migrate" }), true)
	eq(C.state().lock["migrated.nvim"].commit, commit)
end)

test("health check runs with empty state", function()
	H.setup({
		specs = {},
		lock = {},
		lock_path = tmp .. "/lock.json",
		config_lock = tmp .. "/config-lock.json",
		pack_dir = tmp .. "/pack",
	})
	local ok, err = pcall(H.check)
	if not ok then
		error(err)
	end
end)

vim.fn.delete(tmp, "rf")
io.write(string.format("\n%d passed, %d failed\n", passed, failed))
if failed > 0 then
	vim.cmd("cquit 1")
else
	vim.cmd("qall!")
end
