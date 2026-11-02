local U = require("nazoplug.util")
local S = require("nazoplug.spec")
local C = require("nazoplug.spec_cache")

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
local config_home = U.join(tmp, "config")
local config = U.join(config_home, "nvim")
local data = U.join(tmp, "data")
local cache = U.join(tmp, "cache")
for _, path in ipairs({ config, data, cache, U.join(config, "lua/plugins") }) do
	vim.fn.mkdir(path, "p")
end
vim.env.XDG_CONFIG_HOME = config_home
vim.env.XDG_DATA_HOME = data
vim.env.XDG_CACHE_HOME = cache
vim.opt.runtimepath:prepend(config)

local source = U.join(config, "lua/plugins/example.lua")
local pack_dir = U.join(data, "site/pack/nazoplug/opt")
U.write_file(
	source,
	[[
return {
  { "owner/example.nvim", opts = { answer = 42 }, cmd = "Example" },
}
]]
)
U.write_file(U.join(config, "lua/plugins.lua"), [[return { import = "plugins.example" }]])

test("spec cache saves and restores specs", function()
	local specs, by_name = S.collect({ import = "plugins.example" }, { source = source, pack_dir = pack_dir })
	eq(#specs, 1)
	eq(by_name["example.nvim"].opts, { answer = 42 })
	local saved, err = C.save(specs)
	assert(saved, err)
	local cached, cached_by_name = C.load()
	eq(#cached, 1)
	eq(cached_by_name["example.nvim"].cmd, { "Example" })
	eq(cached_by_name["example.nvim"].opts, { answer = 42 })
end)

test("spec cache rejects a changed source", function()
	local specs = S.collect({ import = "plugins.example" }, { source = source, pack_dir = pack_dir })
	assert(C.save(specs))
	U.write_file(source, [[return { { "owner/example.nvim", opts = { answer = 43 } } }]])
	local cached = C.load()
	eq(cached, nil)
end)

test("spec cache stores plain keys without needing hydration", function()
	package.loaded["plugins.example"] = nil
	U.write_file(source, [[return { { "owner/example.nvim", keys = { "<leader>ex" } } } ]])
	local specs = S.collect({ import = "plugins.example" }, { source = source, pack_dir = pack_dir })
	assert(C.save(specs))
	assert(U.is_file(C.path()), "json cache should be written")
	local cached, cached_by_name = C.load()
	eq(#cached, 1)
	eq(cached_by_name["example.nvim"].keys, { "<leader>ex" })
	eq(cached_by_name["example.nvim"]._.needs_hydrate, false)
end)

test("spec cache is private and drops executable legacy caches", function()
	package.loaded["plugins.example"] = nil
	U.write_file(source, [[return { { "owner/example.nvim" } }]])
	local specs = S.collect({ import = "plugins.example" }, { source = source, pack_dir = pack_dir })
	local legacy = U.join(vim.fn.stdpath("cache"), "nazoplug", "spec-cache.lua")
	assert(U.write_file(legacy, [[error("legacy cache executed")]]))
	assert(C.save(specs))
	eq(U.is_file(legacy), false)
	assert(U.is_file(C.path()), "json cache should be written")
	eq(vim.fn.getfperm(C.path()), "rw-------")
end)

test("spec cache never executes a legacy cache file", function()
	local marker = U.join(tmp, "legacy-executed.txt")
	vim.fn.delete(C.path())
	local legacy = U.join(vim.fn.stdpath("cache"), "nazoplug", "spec-cache.lua")
	U.write_file(
		legacy,
		string.format(
			[[local f = io.open(%q, "w"); f:write("x"); f:close(); return {version=3,specs={},sources={},directories={}}]],
			marker
		)
	)
	eq(C.load(), nil)
	eq(U.exists(marker), false)
	vim.fn.delete(legacy)
end)

test("spec cache ignores a forged json cache", function()
	U.write_file(
		C.path(),
		'{"version":3,"fingerprint":"x","sources":[],"directories":[],"specs":[{"name":"evil.nvim"}]}'
	)
	eq(C.load(), nil)
end)

test("spec cache marks function keys for hydration", function()
	package.loaded["plugins.example"] = nil
	U.write_file(source, [[return { { "owner/example.nvim", keys = { { "<leader>ex", function() end } } } } ]])
	local specs = S.collect({ import = "plugins.example" }, { source = source, pack_dir = pack_dir })
	assert(C.save(specs))
	local cached, cached_by_name = C.load()
	eq(#cached, 1)
	eq(cached_by_name["example.nvim"].keys, nil)
	eq(cached_by_name["example.nvim"]._.needs_hydrate, true)
end)

vim.fn.delete(tmp, "rf")
io.write(string.format("\n%d passed, %d failed\n", passed, failed))
if failed > 0 then
	vim.cmd("cquit 1")
else
	vim.cmd("qall!")
end
