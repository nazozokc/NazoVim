local M = {}

local title = "NazoVim GitHub PR Details"

local function repository_root()
	return vim.fs.root(0, ".git") or vim.fn.getcwd()
end

local function run(arguments, callback, show_nonzero)
	if vim.fn.executable("gh") ~= 1 then
		vim.notify("GitHub CLI (gh) is required", vim.log.levels.ERROR, { title = title })
		return
	end
	vim.system(vim.list_extend({ "gh" }, arguments), { cwd = repository_root(), text = true }, function(result)
		vim.schedule(function()
			if result.code ~= 0 and not show_nonzero then
				local message = vim.trim(result.stderr or "")
				vim.notify(
					message ~= "" and message or "GitHub CLI command failed",
					vim.log.levels.ERROR,
					{ title = title }
				)
				return
			end
			callback(result)
		end)
	end)
end

local function decode(output)
	local ok, value = pcall(vim.json.decode, output)
	if ok and type(value) == "table" then
		return value
	end
	return nil
end

---Owner, repository name and number of a pull request URL.
local function pull_request_url(item)
	return tostring(item.url):match("^https?://[^/]+/([^/]+)/([^/]+)/pull/(%d+)")
end

local function open_view(name, lines, filetype)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(buf, "NazoGitHub://" .. name .. "/" .. buf)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = filetype or "markdown"
	vim.bo[buf].swapfile = false
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.cmd("botright split")
	vim.api.nvim_win_set_buf(0, buf)
	vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, desc = "Close GitHub view" })
	return buf
end

local function map_line(buf, key, lookup, action)
	vim.keymap.set("n", key, function()
		local entry = lookup[vim.api.nvim_win_get_cursor(0)[1]]
		if entry then
			action(entry)
		end
	end, { buffer = buf, desc = "Open GitHub entry" })
end

local function show_commit(item, owner, name, commit)
	run({
		"api",
		"-H",
		"Accept: application/vnd.github.diff",
		"repos/" .. owner .. "/" .. name .. "/commits/" .. commit.oid,
	}, function(result)
		local lines = {
			string.format("# %s · %s", commit.oid:sub(1, 7), commit.messageHeadline or ""),
			"",
		}
		local body = vim.trim(result.stdout or "")
		if body == "" then
			body = "No textual diff was returned for this commit."
		end
		vim.list_extend(lines, vim.split(body, "\n", { plain = true }))
		open_view("commit/" .. commit.oid:sub(1, 7) .. "/" .. item.number, lines, "diff")
	end)
end

local function show_commits(item, owner, name)
	run({ "pr", "view", tostring(item.url), "--json", "commits" }, function(result)
		local data = decode(result.stdout or "")
		local commits = data and data.commits or {}
		local lines = {
			string.format("# Commits · PR #%s %s", item.number, item.title),
			"Actions: <CR> show diff · gx open commit · q close",
			"",
		}
		local lookup = {}
		for _, commit in ipairs(commits) do
			local author = commit.authors and commit.authors[1] and commit.authors[1].login or "unknown"
			lines[#lines + 1] = string.format(
				"%s %s %s %s",
				commit.oid:sub(1, 7),
				(commit.committedDate or ""):sub(1, 10),
				author,
				commit.messageHeadline or ""
			)
			lookup[#lines] = commit
		end
		if #commits == 0 then
			lines[#lines + 1] = "No commits were returned."
		end
		local buf = open_view("pr-commits/" .. item.number, lines)
		map_line(buf, "<CR>", lookup, function(commit)
			show_commit(item, owner, name, commit)
		end)
		map_line(buf, "gx", lookup, function(commit)
			vim.ui.open(string.format("https://github.com/%s/%s/commit/%s", owner, name, commit.oid))
		end)
	end)
end

local function file_lines(file)
	local added = tonumber(file.additions) or 0
	local removed = tonumber(file.deletions) or 0
	return string.format("%-8s %s (+%d -%d)", file.status or "changed", file.filename or "", added, removed)
end

local function show_file(file)
	local patch = vim.trim(file.patch or "")
	local lines = {
		string.format("# %s · %s", file.status or "changed", file.filename or ""),
		string.format(
			"+%d -%d · gx open file · q close",
			tonumber(file.additions) or 0,
			tonumber(file.deletions) or 0
		),
		"",
	}
	if patch == "" then
		lines[#lines + 1] = "No textual patch was returned. The file may be binary or too large."
	else
		vim.list_extend(lines, vim.split(patch, "\n", { plain = true }))
	end
	open_view("file/" .. (file.filename or "unknown"):gsub("[^%w%-%._/]", "_"), lines, "diff")
end

local function show_files(item, owner, name, number)
	run({
		"api",
		"--paginate",
		string.format("repos/%s/%s/pulls/%s/files?per_page=100", owner, name, number),
		"--jq",
		".[]",
	}, function(result)
		local files = {}
		for _, line in ipairs(vim.split(vim.trim(result.stdout or ""), "\n", { plain = true })) do
			local file = line ~= "" and decode(line) or nil
			if file then
				files[#files + 1] = file
			end
		end
		local lines = {
			string.format("# Changed files · PR #%s %s", item.number, item.title),
			"Actions: <CR> show patch · gx open file · q close",
			"",
		}
		local lookup = {}
		for _, file in ipairs(files) do
			lines[#lines + 1] = file_lines(file)
			lookup[#lines] = file
		end
		if #files == 0 then
			lines[#lines + 1] = "No changed files were returned."
		end
		local buf = open_view("pr-files/" .. item.number, lines)
		map_line(buf, "<CR>", lookup, show_file)
		map_line(buf, "gx", lookup, function(file)
			vim.ui.open(file.blob_url or item.url)
		end)
	end)
end

local function show_checks(item)
	run(
		{ "pr", "checks", tostring(item.url), "--json", "bucket,name,state,workflow,description,link" },
		function(result)
			local checks = decode(result.stdout or "")
			local lines = {
				string.format("# Checks · PR #%s %s", item.number, item.title),
				"Actions: <CR> or gx open check run · q close",
				"",
			}
			local lookup = {}
			for _, check in ipairs(checks or {}) do
				local workflow = check.workflow ~= "" and (" · " .. check.workflow) or ""
				lines[#lines + 1] = string.format(
					"%-8s %s · %s%s",
					check.bucket or "unknown",
					check.name or "check",
					check.state or "",
					workflow
				)
				lookup[#lines] = check
				if check.description and check.description ~= "" then
					lines[#lines + 1] = "  " .. check.description
				end
			end
			if not checks then
				vim.list_extend(
					lines,
					vim.split(
						vim.trim(result.stdout ~= "" and result.stdout or result.stderr or ""),
						"\n",
						{ plain = true }
					)
				)
			elseif #checks == 0 then
				lines[#lines + 1] = "No check runs were returned."
			end
			local buf = open_view("pr-checks/" .. item.number, lines)
			local function open(check)
				vim.ui.open(check.link or item.url)
			end
			map_line(buf, "<CR>", lookup, open)
			map_line(buf, "gx", lookup, open)
		end,
		true
	)
end

local function choose_view(item)
	local owner, name, number = pull_request_url(item)
	if not owner then
		vim.notify("Could not identify this pull request's repository", vim.log.levels.ERROR, { title = title })
		return
	end
	local views = {
		{
			label = "Commits",
			run = function()
				show_commits(item, owner, name)
			end,
		},
		{
			label = "Changed files",
			run = function()
				show_files(item, owner, name, number)
			end,
		},
		{
			label = "Check runs",
			run = function()
				show_checks(item)
			end,
		},
		{
			label = "Open pull request on GitHub",
			run = function()
				vim.ui.open(item.url)
			end,
		},
	}
	vim.ui.select(views, {
		prompt = string.format("PR #%s · %s", item.number, item.title),
		format_item = function(view)
			return view.label
		end,
	}, function(view)
		if view then
			view.run()
		end
	end)
end

function M.open()
	run(
		{ "pr", "list", "--state", "all", "--limit", "100", "--json", "number,title,url,state,isDraft" },
		function(result)
			local items = decode(result.stdout or "")
			if not items then
				vim.notify("Could not decode pull request list", vim.log.levels.ERROR, { title = title })
				return
			end
			if #items == 0 then
				vim.notify("No pull requests found", vim.log.levels.INFO, { title = title })
				return
			end
			vim.ui.select(items, {
				prompt = "GitHub pull request details",
				format_item = function(item)
					return string.format("#%s %s · %s", item.number, item.title, (item.state or ""):lower())
				end,
			}, function(item)
				if item then
					choose_view(item)
				end
			end)
		end
	)
end

function M.setup()
	vim.api.nvim_create_user_command("NazoGitHubPRDetails", M.open, {
		desc = "Inspect GitHub pull request commits, changed files and checks",
	})
	vim.keymap.set("n", "<leader>oC", M.open, { desc = "GitHub Pull Request Details" })
end

return M
