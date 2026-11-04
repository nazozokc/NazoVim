-- Exercises the GitHub modules against a fake `gh` so no network or auth is needed.
vim.opt.rtp:prepend("apps/nvim")
vim.o.swapfile = false

local log = vim.fn.tempname() .. "-gh.log"
local bindir = vim.fn.tempname()
vim.fn.mkdir(bindir, "p")
local script = bindir .. "/gh"
local body = [==[
#!/bin/sh
printf '%s\n' "$*" >> "$GH_CALL_LOG"
case "$1 $2" in
"pr list")
	printf '%s\n' '[{"number":7,"title":"Add feature","url":"https://github.com/o/r/pull/7","state":"OPEN","isDraft":false}]'
	;;
"pr view")
	printf '%s\n' '{"commits":[{"oid":"aaaa1111222233334444555566667777888899990a","messageHeadline":"first commit","committedDate":"2026-11-01T00:00:00Z","authors":[{"login":"nazo"}]}]}'
	;;
"pr checks")
	printf '%s\n' '[{"bucket":"pass","name":"lint","state":"SUCCESS","workflow":"CI","description":"ok","link":"https://example.com/run/1"}]'
	;;
"api -H")
	printf '%s\n' 'diff --git a/a.lua b/a.lua' '@@ -1 +1 @@' '-old' '+new'
	;;
"api --paginate")
	case "$3" in
	gists*)
		printf '%s\n' '{"id":"aaa111","description":"notes","public":false,"updated_at":"2026-10-13T13:09:51Z","files":["session.html"]}'
		printf '%s\n' '{"id":"bbb222","description":"snippet","public":true,"updated_at":"2026-09-01T00:00:00Z","files":["a.lua"]}'
		;;
	*)
		printf '%s\n' '{"filename":"apps/a.lua","status":"modified","additions":2,"deletions":1,"patch":"@@ -1 +1 @@","blob_url":"https://github.com/o/r/blob/main/apps/a.lua"}'
		;;
	esac
	;;
"project list")
	printf '%s\n' '{"projects":[{"number":3,"title":"Roadmap","closed":false,"id":"PVT_1"}]}'
	;;
"project field-list")
	printf '%s\n' '{"fields":[{"id":"PVTF_2","name":"Estimate","type":"ProjectV2NumberField"},{"id":"PVTSSF_1","name":"Status","type":"ProjectV2SingleSelectField","options":[{"id":"opt1","name":"Todo"},{"id":"opt2","name":"In progress"},{"id":"opt3","name":"Done"}]}]}'
	;;
"project item-list")
	printf '%s\n' '{"items":[{"id":"PVTI_1","status":"Todo","content":{"number":12,"title":"Fix the thing","type":"Issue","url":"https://github.com/o/r/issues/12"}}]}'
	;;
"project item-edit" | "project item-archive" | "project item-add" | "project view")
	printf '%s\n' '{}'
	;;
"issue list")
	printf '%s\n' '[{"number":12,"title":"Fix the thing","url":"https://github.com/o/r/issues/12"}]'
	;;
*)
	printf 'unexpected gh call: %s\n' "$*" >&2
	exit 1
	;;
esac
]==]
vim.fn.writefile(vim.split(body, "\n", { plain = true }), script)
vim.fn.setfperm(script, "rwxr-xr-x")
vim.env.GH_CALL_LOG = log
vim.env.PATH = bindir .. ":" .. vim.env.PATH
assert(vim.fn.executable("gh") == 1, "fake gh is not executable")

local calls = {}
local function read_log()
	if vim.fn.filereadable(log) == 0 then
		return ""
	end
	calls = vim.fn.readfile(log)
	return table.concat(calls, "\n")
end

local function wait_for(pattern, label)
	local ok = vim.wait(10000, function()
		return read_log():find(pattern, 1, true) ~= nil
	end, 50)
	assert(ok, "timed out waiting for " .. (label or pattern) .. "\nlog:\n" .. read_log())
end

local function item_text(item)
	if type(item) ~= "table" then
		return tostring(item)
	end
	return item.label or item.name or item.title or ""
end

local function pick(text)
	return function(items, opts, on_choice)
		local function render(item)
			if opts and opts.format_item then
				return opts.format_item(item)
			end
			return item_text(item)
		end
		for _, item in ipairs(items) do
			if render(item) == text then
				return on_choice(item)
			end
		end
		error(
			string.format(
				"%s: no item %q in %s",
				tostring(opts and opts.prompt),
				text,
				vim.inspect(vim.tbl_map(render, items))
			)
		)
	end
end

local handlers = {}
local function handle(match, callback)
	handlers[#handlers + 1] = { match = match, callback = callback }
end

vim.ui.select = function(items, opts, on_choice)
	local prompt = tostring(opts and opts.prompt or "")
	for index, handler in ipairs(handlers) do
		if prompt:find(handler.match, 1, true) then
			-- Each registration answers one prompt so repeated prompts (an item
			-- action chosen twice) can be scripted separately.
			table.remove(handlers, index)
			return handler.callback(items, opts, on_choice)
		end
	end
	error("unexpected select prompt: " .. prompt)
end

local function buffer_named(pattern)
	local name = vim.api.nvim_buf_get_name(0)
	return name:find(pattern) ~= nil
end

local function wait_view(pattern, minimum_lines)
	local ok = vim.wait(10000, function()
		return buffer_named(pattern) and vim.api.nvim_buf_line_count(0) >= (minimum_lines or 4)
	end, 50)
	assert(ok, "view missing: " .. pattern .. " current=" .. vim.api.nvim_buf_get_name(0))
end

local function press(keys)
	vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "x", false)
end

local function close_views()
	pcall(vim.cmd, "silent! only")
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_get_name(buf):find("NazoGitHub://") then
			pcall(vim.api.nvim_buf_delete, buf, { force = true })
		end
	end
	handlers = {}
end

-- Commands and keymaps are registered by setup().
require("nazovim.github_gists").setup()
require("nazovim.github_pr_details").setup()
require("nazovim.github_projects").setup()
for _, command in ipairs({ "NazoGitHubGists", "NazoGitHubPRDetails", "NazoGitHubProjects" }) do
	assert(vim.fn.exists(":" .. command) == 2, command .. " is missing")
end
for _, lhs in ipairs({ "<leader>oG", "<leader>oC", "<leader>oB" }) do
	assert(vim.fn.maparg(lhs, "n") ~= "", lhs .. " is missing")
end

-- Gists: list, open and copy.
local opened
vim.ui.open = function(url)
	opened = url
end
require("nazovim.github_gists").open()
wait_view("NazoGitHub://gists", 5)
local gist_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
assert(gist_lines[4]:find("session.html", 1, true), "first gist line: " .. gist_lines[4])
vim.api.nvim_win_set_cursor(0, { 4, 0 })
press("<CR>")
assert(opened == "https://gist.github.com/aaa111", "open gist url: " .. tostring(opened))
vim.api.nvim_win_set_cursor(0, { 5, 0 })
press("y")
assert(vim.fn.getreg('"') == "https://gist.github.com/bbb222", "copied gist url")
close_views()

-- Pull request details: commits, commit diff, changed files and checks.
handle("GitHub pull request details", pick("#7 Add feature · open"))
handle("PR #7", pick("Commits"))
local details = require("nazovim.github_pr_details")
details.open()
wait_view("NazoGitHub://pr%-commits/7", 4)
local commit_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
assert(commit_lines[4]:find("aaaa111", 1, true), "commit line: " .. commit_lines[4])
vim.api.nvim_win_set_cursor(0, { 4, 0 })
press("<CR>")
wait_view("NazoGitHub://commit/", 4)
local diff_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
assert(diff_lines[1]:find("aaaa111", 1, true), "commit header: " .. diff_lines[1])
assert(table.concat(diff_lines, "\n"):find("+new", 1, true), "commit diff body is missing")
assert(vim.bo.filetype == "diff", "commit diff filetype: " .. vim.bo.filetype)
close_views()

handle("GitHub pull request details", pick("#7 Add feature · open"))
handle("PR #7", pick("Changed files"))
details.open()
wait_view("NazoGitHub://pr%-files/7", 4)
local file_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
assert(file_lines[4]:find("apps/a.lua", 1, true), "changed file line: " .. file_lines[4])
vim.api.nvim_win_set_cursor(0, { 4, 0 })
press("<CR>")
wait_view("NazoGitHub://file/", 4)
assert(vim.bo.filetype == "diff", "file patch filetype: " .. vim.bo.filetype)
close_views()

handle("GitHub pull request details", pick("#7 Add feature · open"))
handle("PR #7", pick("Check runs"))
details.open()
wait_view("NazoGitHub://pr%-checks/7", 5)
local check_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
assert(check_lines[4]:find("lint", 1, true), "check line: " .. check_lines[4])
assert(table.concat(check_lines, "\n"):find("· CI", 1, true), "check workflow is missing")
opened = nil
vim.api.nvim_win_set_cursor(0, { 4, 0 })
press("gx")
assert(opened == "https://example.com/run/1", "check link: " .. tostring(opened))
close_views()

-- Projects: items, status move, archive and add.
local projects = require("nazovim.github_projects")
handle("GitHub projects for", pick("#3 Roadmap"))
handle("Project #3", pick("Items"))
projects.open()
wait_view("NazoGitHub://project/3", 4)
local item_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
assert(item_lines[4]:find("Fix the thing", 1, true), "project item line: " .. item_lines[4])
assert(item_lines[4]:find("Todo", 1, true), "project item status: " .. item_lines[4])

handle("Fix the thing", pick("Move to another Status value"))
handle("Move item to Status", pick("In progress"))
vim.api.nvim_win_set_cursor(0, { 4, 0 })
press("<CR>")
wait_for("project item-edit 3 --owner", "item-edit call")
assert(
	read_log():find("--field Status --value In progress --url https://github.com/o/r/issues/12", 1, true),
	"item-edit arguments:\n" .. read_log()
)
vim.wait(1000, function()
	return vim.api.nvim_buf_get_lines(0, 3, 4, false)[1]:find("In progress", 1, true) ~= nil
end, 50)

handle("Fix the thing", pick("Archive item"))
handle("Archive this project item?", pick("Confirm"))
vim.api.nvim_win_set_cursor(0, { 4, 0 })
press("<CR>")
wait_for("project item-archive 3 --owner", "item-archive call")
assert(read_log():find("--id PVTI_1", 1, true), "item-archive arguments:\n" .. read_log())
close_views()

local lists_before = select(2, read_log():gsub("project item%-list", ""))
handle("GitHub projects for", pick("#3 Roadmap"))
handle("Project #3", pick("Add issue or pull request"))
handle("Add to Roadmap", pick("PR #7 Add feature"))
projects.open()
wait_for("project item-add 3 --owner", "item-add call")
assert(
	read_log():find("--url https://github.com/o/r/pull/7", 1, true),
	"item-add should prefer pull requests:\n" .. read_log()
)
-- Wait for the refresh that follows the add so no callback outlives the summary.
assert(
	vim.wait(10000, function()
		return select(2, read_log():gsub("project item%-list", "")) > lists_before
	end, 50),
	"item-add did not refresh the item list"
)
close_views()

-- Let scheduled callbacks (and their notifications) finish before the summary.
vim.wait(500, function()
	return false
end, 10)
vim.fn.delete(bindir, "rf")
vim.fn.delete(log)
print("github: gists, PR details and projects passed")
vim.cmd("qall!")
