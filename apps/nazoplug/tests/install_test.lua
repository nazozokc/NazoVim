local U = require("nazoplug.util")
local S = require("nazoplug.spec")
local L = require("nazoplug.lock")
local G = require("nazoplug.git")
local I = require("nazoplug.install")
local MG = require("nazoplug.migrate")

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

local function commit(repo, message)
	vim.fn.writefile({ message }, U.join(repo, "file.txt"))
	truthy(G.run({ "add", "." }, { cwd = repo }))
	truthy(G.run({ "commit", "-m", message }, { cwd = repo }))
	return truthy(G.head(repo))
end

local tmp = vim.fn.tempname()
vim.fn.mkdir(tmp, "p")
vim.env.XDG_DATA_HOME = U.join(tmp, "data")
vim.fn.mkdir(U.join(tmp, "data"), "p")
local origin = U.join(tmp, "origin")
local pack_dir = U.join(tmp, "pack")
vim.fn.mkdir(origin, "p")
truthy(G.run({ "init", "-b", "main" }, { cwd = origin }))
truthy(G.run({ "config", "user.email", "test@example.com" }, { cwd = origin }))
truthy(G.run({ "config", "user.name", "Test" }, { cwd = origin }))
local first = commit(origin, "one")
truthy(G.run({ "tag", "v1.0.0" }, { cwd = origin }))
truthy(G.run({ "branch", "v3.x" }, { cwd = origin }))
local second = commit(origin, "two")
truthy(G.run({ "tag", "v1.1.0" }, { cwd = origin }))

local function spec(extra)
	local values = { url = origin, name = "demo.nvim" }
	for key, value in pairs(extra or {}) do
		values[key] = value
	end
	local _, by_name = S.collect({ values }, { pack_dir = pack_dir })
	return by_name[values.name]
end

test("git clone and version checkout", function()
	local s = spec({ version = "^1.0" })
	local entry, err = I.ensure(s, {})
	truthy(entry, err)
	eq(entry.commit, second)
	eq(G.head(s.dir), second)
	eq(G.current_branch(s.dir), nil)
end)

test("git exact tag checkout", function()
	local s = spec({ name = "tagged.nvim", tag = "v1.0.0" })
	local entry, err = I.ensure(s, {})
	truthy(entry, err)
	eq(entry.commit, first)
	eq(entry.branch, nil)
	eq(G.head(s.dir), first)
	eq(G.current_branch(s.dir), nil)
	truthy(I.check(s, { [s.name] = entry }))
end)

test("sync detaches tags even when the lock records a branch", function()
	local s = spec({ name = "tagged-sync.nvim", tag = "v1.1.0" })
	local entry = truthy(I.ensure(s, {}))
	truthy(G.run({ "checkout", "main" }, { cwd = s.dir }))
	eq(G.current_branch(s.dir), "main")
	eq(G.head(s.dir), entry.commit)
	local ok, results, sync_failed = I.sync({ s }, { [s.name] = { commit = entry.commit, branch = "main" } }, {})
	truthy(ok, vim.inspect(sync_failed or results))
	eq(G.current_branch(s.dir), nil)
	eq(G.head(s.dir), entry.commit)
end)

test("git fetches a tag missing locally", function()
	local s = spec({ name = "remote-tag.nvim", tag = "v1.1.0" })
	truthy(G.clone(s, {}))
	truthy(G.run({ "tag", "-d", "v1.1.0" }, { cwd = s.dir }))
	local entry, err = I.ensure(s, {})
	truthy(entry, err)
	eq(entry.commit, second)
	eq(G.current_branch(s.dir), nil)
end)

test("install new plugin from locked commit", function()
	local s = spec({ name = "locked-install.nvim" })
	local lock = { [s.name] = { commit = first } }
	local ok, results = I.install({ s }, lock, { update = false, use_lock = "missing" })
	truthy(ok, vim.inspect(results))
	eq(G.head(s.dir), first)
end)

test("pinned plugin keeps its locked commit on update", function()
	local s = spec({ name = "pinned.nvim", pin = true })
	local entry = truthy(I.ensure(s, {}))
	local third = commit(origin, "pinned update")
	local updated, err = I.ensure(s, { update = true, lock = { [s.name] = entry } })
	truthy(updated, err)
	eq(updated.commit, entry.commit)
	eq(G.head(s.dir), entry.commit)
	eq(third ~= entry.commit, true)
end)

test("install_missing keeps a pinned parent instead of repinning HEAD", function()
	local pack = U.join(tmp, "pin-pack")
	local head = truthy(G.head(origin))
	local _, by_name = S.collect({
		{
			name = "pin-parent.nvim",
			url = origin,
			dependencies = { { name = "pin-child.nvim", url = origin } },
		},
	}, { pack_dir = pack })
	local parent, child = by_name["pin-parent.nvim"], by_name["pin-child.nvim"]
	local lock = {}
	local ok, results = I.install({ parent }, lock, { update = false, by_name = by_name })
	truthy(ok, vim.inspect(results))
	eq(lock[parent.name].commit, head)
	-- Move the working tree off the pin, then force the parent into the install
	-- set by deleting a dependency.
	truthy(G.checkout(parent.dir, first))
	eq(G.head(parent.dir), first)
	vim.fn.delete(child.dir, "rf")
	truthy(I.install_missing({ parent }, lock, { by_name = by_name }))
	eq(lock[parent.name].commit, head, "lock pin must not follow HEAD")
end)

test("sync does not fetch when the locked commit is already checked out", function()
	local s = spec({ name = "offline-sync.nvim" })
	local entry = truthy(I.ensure(s, {}))
	local backup = origin .. "-offline"
	truthy(vim.uv.fs_rename(origin, backup))
	local ok, results, sync_failed = I.sync({ s }, { [s.name] = entry }, {})
	truthy(vim.uv.fs_rename(backup, origin))
	truthy(ok, vim.inspect(sync_failed or results))
	eq(G.head(s.dir), entry.commit)
end)

test("sync restores the default branch after a detached checkout", function()
	local s = spec({ name = "default-sync.nvim" })
	local entry = truthy(I.ensure(s, {}))
	eq(entry.branch, "main")
	truthy(G.checkout(s.dir, entry.commit))
	eq(G.current_branch(s.dir), nil)
	local checked, check_err = I.check(s, { [s.name] = entry })
	eq(checked, true)
	eq(check_err, entry.commit)
	local ok, results, sync_failed = I.sync({ s }, { [s.name] = entry }, {})
	truthy(ok, vim.inspect(sync_failed or results))
	eq(G.current_branch(s.dir), "main")
end)

test("check reports a branch mismatch", function()
	local s = spec({ name = "branch-check.nvim" })
	local entry = truthy(I.ensure(s, {}))
	truthy(G.run({ "checkout", "-b", "other" }, { cwd = s.dir }))
	local checked, check_err = I.check(s, { [s.name] = entry })
	eq(checked, false)
	eq(check_err, "branch mismatch")
end)

test("sync follows a changed spec branch", function()
	local s = spec({ name = "branch-change.nvim" })
	local entry = truthy(I.ensure(s, {}))
	eq(entry.branch, "main")
	s.branch = "v3.x"
	local ok, results, sync_failed = I.sync({ s }, { [s.name] = entry }, {})
	truthy(ok, vim.inspect(sync_failed or results))
	eq(G.current_branch(s.dir), "v3.x")
	eq(G.head(s.dir), entry.commit)
end)

test("git branch checkout and update", function()
	local s = spec({ branch = "v3.x" })
	local entry, err = I.ensure(s, {})
	truthy(entry, err)
	eq(entry.commit, first)
	eq(entry.branch, "v3.x")
	eq(G.current_branch(s.dir), "v3.x")
end)

test("sync restores the locked commit and branch", function()
	local s = spec({ branch = "v3.x" })
	local entry = truthy(I.ensure(s, {}))
	eq(entry.commit, first)
	commit(origin, "four")
	local ok, _, sync_failed = I.sync({ s }, { [s.name] = entry }, {})
	truthy(ok, vim.inspect(sync_failed))
	eq(G.head(s.dir), first)
	eq(G.current_branch(s.dir), "v3.x")
end)

test("git update to new default commit", function()
	local s = spec({})
	truthy(I.ensure(s, {}))
	local third = commit(origin, "three")
	local entry, err = I.ensure(s, { update = true })
	truthy(entry, err)
	eq(entry.commit, third)
	eq(G.head(s.dir), third)
	truthy(I.check(s, { [s.name] = entry }))
end)

test("installer installs dependency before parent", function()
	local child = spec({ name = "child.nvim" })
	local parent = spec({ name = "parent.nvim", dependencies = { { url = origin, name = "child.nvim" } } })
	local lock = {}
	local ok, results = I.install({ parent, child }, lock, { update = false })
	truthy(ok, results)
	truthy(U.is_dir(child.dir))
	truthy(U.is_dir(parent.dir))
	truthy(lock["child.nvim"])
	truthy(lock["parent.nvim"])
end)

test("installer resolves dependencies from by_name for a subset", function()
	local child = spec({ name = "subset-child.nvim" })
	local parent =
		spec({ name = "subset-parent.nvim", dependencies = { { url = origin, name = "subset-child.nvim" } } })
	local by_name = { [child.name] = child, [parent.name] = parent }
	local lock = {}
	local ok, results = I.install({ parent }, lock, { update = false, by_name = by_name })
	truthy(ok, results)
	truthy(U.is_dir(child.dir))
	truthy(U.is_dir(parent.dir))
end)

test("install_missing installs missing dependencies of an installed parent", function()
	local _, by_name = S.collect({
		{
			name = "missing-parent.nvim",
			url = origin,
			dependencies = { { url = origin, name = "missing-child.nvim" } },
		},
	}, { pack_dir = pack_dir })
	local parent = by_name["missing-parent.nvim"]
	local child = by_name["missing-child.nvim"]
	truthy(I.install({ parent }, {}, { update = false, by_name = by_name }))
	vim.fn.delete(child.dir, "rf")
	local ok, results = I.install_missing({ parent }, {}, { by_name = by_name })
	truthy(ok, vim.inspect(results))
	truthy(U.is_dir(child.dir))
end)

test("installer can install a dependency selected directly", function()
	local _, by_name = S.collect({
		{
			name = "direct-parent.nvim",
			url = origin,
			dependencies = { { url = origin, name = "direct-child.nvim" } },
		},
	}, { pack_dir = pack_dir })
	local child = by_name["direct-child.nvim"]
	eq(child._.top, false)
	local ok, results = I.install({ child }, {}, { update = false, by_name = by_name })
	truthy(ok, results)
	truthy(U.is_dir(child.dir))
end)

test("build shell hook runs in plugin dir", function()
	local s = spec({ name = "build.nvim", build = "printf built > built.txt" })
	local entry, err = I.ensure(s, {})
	truthy(entry, err)
	eq(U.read_file(U.join(s.dir, "built.txt")), "built")
end)

test("build reruns on update", function()
	local s = spec({ name = "rebuild.nvim", build = "printf x >> built.txt" })
	truthy(I.ensure(s, {}))
	eq(U.read_file(U.join(s.dir, "built.txt")), "x")
	truthy(I.ensure(s, { update = true }))
	eq(U.read_file(U.join(s.dir, "built.txt")), "xx")
end)

test("build failure leaves plugin installed and reports error", function()
	local s = spec({ name = "badbuild.nvim", build = "exit 7" })
	local entry, err = I.ensure(s, {})
	truthy(entry)
	truthy(err)
	eq(G.is_repo(s.dir), true)
end)

test("migrate preserves lock entries for missing plugins", function()
	local installed = spec({ name = "migrated.nvim" })
	truthy(I.ensure(installed, {}))
	local missing = spec({ name = "missing.nvim" })
	local path = U.join(tmp, "migrate-lock.json")
	truthy(L.save(path, { ["missing.nvim"] = { branch = "main", commit = first } }))
	local lock, migrated = MG.migrate({ installed, missing }, { lock_path = path })
	truthy(lock, migrated)
	eq(lock["missing.nvim"].commit, first)
	truthy(lock["migrated.nvim"])
	truthy(vim.tbl_contains(migrated, "migrated.nvim") == false)
end)

test("migration marker reports up-to-date after migrate", function()
	local old_pack_dir = U.join(tmp, "old-pack")
	local source_repo = U.join(old_pack_dir, "relocated.nvim")
	vim.fn.mkdir(source_repo, "p")
	truthy(G.run({ "init", "-b", "main" }, { cwd = source_repo }))
	truthy(G.run({ "config", "user.email", "test@example.com" }, { cwd = source_repo }))
	truthy(G.run({ "config", "user.name", "Test" }, { cwd = source_repo }))
	commit(source_repo, "relocated")
	local target = spec({ name = "relocated.nvim" })
	if U.exists(target.dir) then
		truthy(vim.fn.delete(target.dir, "rf") == 0)
	end
	eq(MG.uptodate(old_pack_dir), false)
	local _, migrated = MG.migrate({ target }, { old_pack_dir = old_pack_dir })
	truthy(vim.tbl_contains(migrated, "relocated.nvim"))
	eq(MG.uptodate(old_pack_dir), true)
end)

test("lock save keeps install entries", function()
	local lock = {}
	local s = spec({ name = "lock.nvim" })
	local entry = truthy(I.ensure(s, {}))
	lock[s.name] = entry
	local path = U.join(tmp, "lock.json")
	truthy(L.save(path, lock))
	local loaded = truthy(L.load(path))
	eq(loaded[s.name].commit, entry.commit)
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
