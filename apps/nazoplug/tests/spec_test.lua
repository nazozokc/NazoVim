local U = require("nazoplug.util")
local S = require("nazoplug.spec")
local SS = require("nazoplug.spec_state")
local L = require("nazoplug.lock")

local passed, failed = 0, 0
local failures = {}

local function test(name, fn)
	local ok, err = xpcall(fn, debug.traceback)
	if ok then
		passed = passed + 1
		io.write("ok   " .. name .. "\n")
	else
		failed = failed + 1
		failures[#failures + 1] = { name = name, err = err }
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

local tmp = vim.fn.tempname()
vim.fn.mkdir(tmp, "p")
local pack_dir = U.join(tmp, "pack")
local lock_path = U.join(tmp, "nazoplug-lock.json")

test("normname matches lazy naming", function()
	eq(U.normname("nvim-treesitter"), "treesitter")
	eq(U.normname("plenary.nvim"), "plenary")
	eq(U.normname("mini.ai"), "miniai")
	eq(U.normname("nvim-neoclip.lua"), "neoclip")
	eq(U.normname("copilot.lua"), "copilot")
end)

test("spec collects shorthand and resolves dir", function()
	local specs, by_name = S.collect({ "folke/tokyonight.nvim", { "nvim-lua/plenary.nvim", lazy = false } }, {
		pack_dir = pack_dir,
	})
	eq(#specs, 2)
	eq(specs[1].name, "tokyonight.nvim")
	eq(specs[1].url, "https://github.com/folke/tokyonight.nvim.git")
	eq(specs[1].dir, U.join(pack_dir, "tokyonight.nvim"))
	eq(specs[1].lazy, true)
	eq(specs[2].lazy, false)
	truthy(by_name["plenary.nvim"])
end)

test("spec preserves conditional enabled and cond", function()
	local enabled = function()
		return false
	end
	local _, by_name = S.collect({
		{ "owner/conditional.nvim", enabled = enabled, cond = false },
	}, { pack_dir = pack_dir })
	local spec = by_name["conditional.nvim"]
	eq(spec.enabled, enabled)
	eq(SS.is_enabled(spec), false)
	spec.enabled = true
	eq(SS.is_enabled(spec), false)
	spec.cond = true
	eq(SS.is_enabled(spec), true)
end)

test("spec preserves exact tag and pin", function()
	local _, by_name = S.collect({
		{ "owner/tagged.nvim", tag = "v1.0.0", pin = true },
	}, { pack_dir = pack_dir })
	local spec = by_name["tagged.nvim"]
	eq(spec.tag, "v1.0.0")
	eq(spec.pin, true)
end)

test("spec merges dependency tables and opts", function()
	local specs, by_name = S.collect({
		{
			"owner/one",
			dependencies = {
				"owner/dep",
				{ "owner/dep", opts = { a = 1 } },
				{ "owner/other", opts = { x = 1 } },
			},
		},
		{ "owner/other", opts = { y = 2 }, lazy = false },
	}, { pack_dir = pack_dir })
	eq(#specs, 3)
	eq(by_name.one.dependencies, { "dep", "other" })
	eq(by_name.dep.opts, { a = 1 })
	eq(by_name.other.opts, { x = 1, y = 2 })
	eq(by_name.other.lazy, false)
	eq(by_name.other._.dep, false)
	eq(by_name.other._.top, true)
end)

test("spec imports modules and directories", function()
	local root = U.join(tmp, "imports")
	local files = {
		[U.join(root, "lua/foo/one.lua")] = 'return { "owner/one" }\n',
		[U.join(root, "lua/foo/two.lua")] = 'return { { "owner/two", opts = { a = 1 } } }\n',
		[U.join(root, "lua/bar/init.lua")] = 'return { "owner/bar" }\n',
	}
	for path, data in pairs(files) do
		truthy(U.write_file(path, data))
	end
	vim.opt.runtimepath:append(root)
	local specs = S.collect({ { import = "foo" }, { import = "bar" } }, { pack_dir = pack_dir })
	vim.opt.runtimepath:remove(root)
	eq(#specs, 3)
	local names = vim.tbl_map(function(spec)
		return spec.name
	end, specs)
	table.sort(names)
	eq(names, { "bar", "one", "two" })
end)

test("spec ignores an import group with no specs", function()
	local root = U.join(tmp, "empty-import")
	truthy(U.write_file(U.join(root, "lua/emptygroup/.keep"), ""))
	vim.opt.runtimepath:append(root)
	local specs = S.collect({ { import = "emptygroup" } }, { pack_dir = pack_dir })
	local ok, err = pcall(S.collect, { { import = "missinggroup" } }, { pack_dir = pack_dir })
	vim.opt.runtimepath:remove(root)
	eq(#specs, 0)
	eq(ok, false)
	truthy(tostring(err):find("no specs found", 1, true), "missing group should still fail")
end)

test("spec resolves main by normalized name", function()
	local spec = S.collect({ "owner/nvim-treesitter" }, { pack_dir = pack_dir })[1]
	truthy(U.write_file(U.join(spec.dir, "lua/nvim-treesitter.lua"), "return {}\n"))
	truthy(U.write_file(U.join(spec.dir, "lua/nvim-treesitter/configs.lua"), "return {}\n"))
	eq(SS.resolve_main(spec), "nvim-treesitter")
end)

test("lock saves sorted json and loads it", function()
	local lock = {
		z = { branch = "main", commit = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" },
		a = { commit = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" },
	}
	truthy(L.save(lock_path, lock))
	local text = U.read_file(lock_path)
	eq(
		text,
		'{"a":{"commit":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"},"z":{"branch":"main",'
			.. '"commit":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}}\n'
	)
	local loaded = truthy(L.load(lock_path))
	eq(loaded, lock)
	eq(L.count(loaded), 2)
	eq(L.names(loaded), { "a", "z" })
end)

test("lock missing file is empty", function()
	local lock = truthy(L.load(U.join(tmp, "missing-lock.json")))
	eq(lock, {})
end)

test("lock rejects invalid commit", function()
	local ok, err = L.save(lock_path, { bad = { commit = "xyz" } })
	eq(ok, nil)
	truthy(err)
end)

test("lock diff reports missing and stale", function()
	local lock = {
		old = { commit = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" },
		keep = { commit = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" },
	}
	local missing, stale = L.diff(lock, {
		{ name = "keep" },
		{ name = "new" },
	})
	eq(missing, { "new" })
	eq(stale, { "old" })
end)

test("lock copies config lock to runtime once", function()
	local config = U.join(tmp, "config-lock.json")
	local runtime = U.join(tmp, "runtime-lock.json")
	truthy(L.save(config, { a = { commit = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" } }))
	eq(L.ensure_runtime_copy(config, runtime), runtime)
	truthy(U.exists(runtime))
	local loaded = truthy(L.load(runtime))
	eq(loaded.a.commit, "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
end)

test("util atomic write leaves no temp file", function()
	local path = U.join(tmp, "atomic.json")
	truthy(U.write_atomic(path, "{}\n"))
	eq(U.read_file(path), "{}\n")
	local files = U.list_files(tmp, function(file_path)
		return file_path:match("%.tmp%.") ~= nil
	end)
	eq(#files, 0)
end)

vim.fn.delete(tmp, "rf")

io.write(string.format("\n%d passed, %d failed\n", passed, failed))
if failed > 0 then
	for _, failure in ipairs(failures) do
		io.write("\n" .. failure.name .. "\n" .. failure.err .. "\n")
	end
	vim.cmd("cquit 1")
else
	vim.cmd("qall!")
end
