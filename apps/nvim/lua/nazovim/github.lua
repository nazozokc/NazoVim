local M = {}

local function repository_root()
	return vim.fs.root(0, ".git") or vim.fn.getcwd()
end

local function run(arguments, callback)
	if vim.fn.executable("gh") ~= 1 then
		vim.notify("GitHub CLI (gh) is required", vim.log.levels.ERROR, { title = "NazoVim GitHub" })
		return
	end
	vim.system(vim.list_extend({ "gh" }, arguments), { cwd = repository_root(), text = true }, function(result)
		vim.schedule(function()
			if result.code ~= 0 then
				local message = vim.trim(result.stderr or "")
				vim.notify(message ~= "" and message or "GitHub CLI command failed", vim.log.levels.ERROR, {
					title = "NazoVim GitHub",
				})
				return
			end
			callback(result.stdout or "")
		end)
	end)
end

local function decode_json(output)
	local ok, value = pcall(vim.json.decode, output)
	if not ok then
		vim.notify("Could not decode GitHub CLI response: " .. tostring(value), vim.log.levels.ERROR, {
			title = "NazoVim GitHub",
		})
		return nil
	end
	return value
end

local function label_names(labels)
	local names = {}
	for _, label in ipairs(labels or {}) do
		names[#names + 1] = label.name or tostring(label)
	end
	return table.concat(names, ", ")
end

local function open_composer(kind, mode, item, detail, on_submit)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(
		buf,
		"NazoGitHub://" .. mode .. "/" .. kind .. "/" .. (detail and detail.number or "new") .. "/" .. buf
	)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = "markdown"
	vim.bo[buf].swapfile = false
	local lines = { detail and detail.title or "", "" }
	local body = detail and detail.body or ""
	if body ~= "" then
		vim.list_extend(lines, vim.split(body, "\n", { plain = true }))
	end
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.cmd("botright split")
	vim.api.nvim_win_set_buf(0, buf)
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_var(buf, "nazovim_github_form", {
		kind = kind,
		mode = mode,
		url = item and (item.url or item.number) or nil,
	})
	vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, desc = "Cancel GitHub form" })
	vim.keymap.set("n", "<C-s>", function()
		local content = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		local title = vim.trim(content[1] or "")
		if title == "" then
			vim.notify("A title is required", vim.log.levels.ERROR, { title = "NazoVim GitHub" })
			return
		end
		local body_lines = {}
		for index = 2, #content do
			body_lines[#body_lines + 1] = content[index]
		end
		if body_lines[1] == "" then
			table.remove(body_lines, 1)
		end
		local description = table.concat(body_lines, "\n")
		local subcommand = kind == "issue" and "issue" or "pr"
		local arguments = { subcommand, mode == "create" and "create" or "edit" }
		if mode == "edit" then
			vim.list_extend(arguments, { tostring(item.url or item.number), "--title", title, "--body", description })
		else
			vim.list_extend(arguments, { "--title", title, "--body", description })
		end
		run(arguments, function(output)
			vim.notify(mode == "create" and vim.trim(output) or "GitHub " .. kind .. " updated", vim.log.levels.INFO, {
				title = "NazoVim GitHub",
			})
			if vim.api.nvim_buf_is_valid(buf) then
				vim.api.nvim_buf_delete(buf, { force = true })
			end
			if on_submit then
				on_submit()
			end
		end)
	end, { buffer = buf, desc = "Submit GitHub form" })
	vim.notify("First line: title · remaining lines: body · <C-s> submit · q cancel", vim.log.levels.INFO, {
		title = "NazoVim GitHub",
	})
end

local function show_document(name, lines, url, buf, actions)
	local expanded_lines = {}
	for _, line in ipairs(lines) do
		for _, part in ipairs(vim.split(line, "\n", { plain = true })) do
			expanded_lines[#expanded_lines + 1] = part
		end
	end
	local created = not buf or not vim.api.nvim_buf_is_valid(buf)
	if created then
		buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_name(buf, name)
		vim.bo[buf].buftype = "nofile"
		vim.bo[buf].bufhidden = "wipe"
		vim.bo[buf].filetype = "markdown"
	end
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, expanded_lines)
	vim.bo[buf].modifiable = false
	if created then
		vim.cmd("botright split")
		vim.api.nvim_win_set_buf(0, buf)
	end
	vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, desc = "Close GitHub view" })
	vim.keymap.set("n", "gx", function()
		if url and url ~= "" then
			vim.ui.open(url)
		end
	end, { buffer = buf, desc = "Open on GitHub" })
	for key, action in pairs(actions or {}) do
		vim.keymap.set("n", key, action, { buffer = buf })
	end
	if vim.api.nvim_get_current_buf() == buf then
		vim.api.nvim_win_set_cursor(0, { 1, 0 })
	end
	return buf
end

local function open_detail(kind, item, existing_buf)
	local fields
	if kind == "issue" then
		fields = "number,title,body,state,stateReason,author,assignees,labels,createdAt,updatedAt,url,comments"
	else
		fields =
			"number,title,body,state,isDraft,mergedAt,author,assignees,labels,createdAt,updatedAt,url,headRefName,baseRefName,reviewDecision,additions,deletions,changedFiles"
	end
	run({ kind, "view", tostring(item.url or item.number), "--json", fields }, function(output)
		local detail = decode_json(output)
		if not detail then
			return
		end
		local lines = {
			"# " .. (kind == "issue" and "Issue" or "Pull Request") .. " #" .. detail.number .. " " .. detail.title,
			"",
			"State: " .. tostring(detail.state) .. (detail.isDraft and " (draft)" or ""),
			"Author: " .. ((detail.author and detail.author.login) or "unknown"),
			"Labels: " .. label_names(detail.labels),
			"Created: " .. tostring(detail.createdAt or ""),
			"Updated: " .. tostring(detail.updatedAt or ""),
		}
		if kind == "pr" then
			lines[#lines + 1] = "Branch: " .. tostring(detail.headRefName) .. " → " .. tostring(detail.baseRefName)
			lines[#lines + 1] = "Review: " .. tostring(detail.reviewDecision or "pending")
			lines[#lines + 1] = string.format(
				"Changes: +%s / -%s across %s files",
				tostring(detail.additions or 0),
				tostring(detail.deletions or 0),
				tostring(detail.changedFiles or 0)
			)
		end
		lines[#lines + 1] = "URL: " .. tostring(detail.url or "")
		lines[#lines + 1] = "Actions: e edit · c comment · x close/reopen · gx browser · q close"
		lines[#lines + 1] = ""
		lines[#lines + 1] = type(detail.body) == "string" and detail.body ~= "" and detail.body or "(no description)"
		if kind == "issue" and type(detail.comments) == "table" and #detail.comments > 0 then
			lines[#lines + 1] = ""
			lines[#lines + 1] = "## Comments"
			for _, comment in ipairs(detail.comments) do
				lines[#lines + 1] = ""
				lines[#lines + 1] = "### " .. ((comment.author and comment.author.login) or "unknown")
				lines[#lines + 1] = comment.body or ""
			end
		end
		local doc_buf
		local function refresh()
			if doc_buf and vim.api.nvim_buf_is_valid(doc_buf) then
				open_detail(kind, item, doc_buf)
			end
		end
		local function comment()
			vim.ui.input({ prompt = "GitHub comment: " }, function(body)
				if not body or vim.trim(body) == "" then
					return
				end
				local subcommand = kind == "issue" and "issue" or "pr"
				run({ subcommand, "comment", tostring(item.url or item.number), "--body", body }, function()
					vim.notify("GitHub comment added", vim.log.levels.INFO, { title = "NazoVim GitHub" })
					refresh()
				end)
			end)
		end
		local function toggle_state()
			local merged = kind == "pr" and detail.mergedAt ~= nil
			if merged then
				vim.notify(
					"A merged pull request cannot be reopened",
					vim.log.levels.INFO,
					{ title = "NazoVim GitHub" }
				)
				return
			end
			local is_open = tostring(detail.state):lower() == "open"
			local action = is_open and "close" or "reopen"
			vim.ui.select({ action:sub(1, 1):upper() .. action:sub(2) }, {
				prompt = string.format("%s #%s?", action, detail.number),
			}, function(choice)
				if not choice then
					return
				end
				local subcommand = kind == "issue" and "issue" or "pr"
				run({ subcommand, action, tostring(item.url or item.number) }, function()
					local past_tense = action == "close" and "closed" or "reopened"
					vim.notify("GitHub " .. past_tense, vim.log.levels.INFO, { title = "NazoVim GitHub" })
					refresh()
				end)
			end)
		end
		local function edit()
			open_composer(kind, "edit", item, detail, refresh)
		end
		doc_buf = show_document(
			"NazoGitHub://" .. kind .. "/" .. detail.number,
			vim.split(table.concat(lines, "\n"), "\n", { plain = true }),
			detail.url,
			existing_buf,
			{ e = edit, c = comment, x = toggle_state }
		)
	end)
end

local function create(kind)
	open_composer(kind, "create")
end

local function list(kind)
	local subcommand = kind == "issue" and "issue" or "pr"
	local fields = kind == "issue" and "number,title,state,author,labels,updatedAt,url"
		or "number,title,state,isDraft,author,labels,updatedAt,url,reviewDecision"
	run({ subcommand, "list", "--limit", "100", "--json", fields }, function(output)
		local items = decode_json(output)
		if not items then
			return
		end
		if #items == 0 then
			vim.notify("No open " .. (kind == "issue" and "issues" or "pull requests"), vim.log.levels.INFO, {
				title = "NazoVim GitHub",
			})
			return
		end
		vim.ui.select(items, {
			prompt = kind == "issue" and "GitHub Issues" or "GitHub Pull Requests",
			format_item = function(item)
				local prefix = kind == "issue" and "#" or (item.isDraft and "Draft #" or "#")
				local review = kind == "pr" and item.reviewDecision and (" · " .. item.reviewDecision) or ""
				return string.format(
					"%s%s %s · %s · %s%s",
					prefix,
					item.number,
					item.title,
					item.state,
					(item.author and item.author.login) or "unknown",
					review
				)
			end,
		}, function(item)
			if item then
				open_detail(kind, item)
			end
		end)
	end)
end

function M.issues()
	list("issue")
end

function M.pull_requests()
	list("pr")
end

function M.notifications()
	run({ "api", "notifications?per_page=100" }, function(output)
		local items = decode_json(output)
		if not items then
			return
		end
		if #items == 0 then
			vim.notify("No unread GitHub notifications", vim.log.levels.INFO, { title = "NazoVim GitHub" })
			return
		end
		vim.ui.select(items, {
			prompt = "Unread GitHub Notifications",
			format_item = function(item)
				local subject = item.subject or {}
				local repository = item.repository or {}
				return string.format(
					"%s · %s · %s · %s",
					subject.title or "(untitled)",
					repository.full_name or "unknown repository",
					subject.type or "notification",
					item.reason or ""
				)
			end,
		}, function(item)
			if not item then
				return
			end
			local api_url = item.subject and item.subject.url
			local repository = item.repository or {}
			local resource = type(api_url) == "string" and api_url:match("/repos/(.+)$")
			local url
			if resource and repository.html_url then
				resource = resource:gsub("/pulls/", "/pull/"):gsub("/commits/", "/commit/")
				url = repository.html_url .. "/" .. resource
			elseif type(api_url) == "string" then
				url = api_url:gsub("api%.github%.com/repos/", "github.com/")
				url = url:gsub("/pulls/", "/pull/"):gsub("/commits/", "/commit/")
			elseif repository.html_url then
				url = repository.html_url
			end
			if url then
				vim.ui.open(url)
			end
		end)
	end)
end

function M.search()
	vim.ui.input({ prompt = "Search GitHub issues and PRs: " }, function(query)
		if not query or vim.trim(query) == "" then
			return
		end
		run({
			"search",
			"issues",
			"--include-prs",
			"--limit",
			"100",
			"--json",
			"number,title,state,author,labels,repository,url,isPullRequest,updatedAt",
			"--",
			query,
		}, function(output)
			local items = decode_json(output)
			if not items then
				return
			end
			if #items == 0 then
				vim.notify(
					"No matching GitHub issues or pull requests",
					vim.log.levels.INFO,
					{ title = "NazoVim GitHub" }
				)
				return
			end
			vim.ui.select(items, {
				prompt = "GitHub Search Results",
				format_item = function(item)
					local repository = item.repository and item.repository.nameWithOwner or "unknown repository"
					local kind = item.isPullRequest and "PR" or "Issue"
					return string.format("%s #%s %s · %s · %s", kind, item.number, item.title, repository, item.state)
				end,
			}, function(item)
				if item then
					open_detail(item.isPullRequest and "pr" or "issue", item)
				end
			end)
		end)
	end)
end

function M.create_issue()
	create("issue")
end

function M.create_pull_request()
	create("pr")
end

function M.setup()
	vim.api.nvim_create_user_command("NazoGitHubIssues", M.issues, { desc = "List and inspect repository issues" })
	vim.api.nvim_create_user_command("NazoGitHubPRs", M.pull_requests, { desc = "List and inspect pull requests" })
	vim.api.nvim_create_user_command(
		"NazoGitHubNotifications",
		M.notifications,
		{ desc = "List unread GitHub notifications" }
	)
	vim.api.nvim_create_user_command("NazoGitHubSearch", M.search, { desc = "Search GitHub issues and pull requests" })
	vim.api.nvim_create_user_command("NazoGitHubIssueCreate", M.create_issue, { desc = "Create a GitHub issue" })
	vim.api.nvim_create_user_command("NazoGitHubPRCreate", M.create_pull_request, { desc = "Create a GitHub pull request" })
	vim.keymap.set("n", "<leader>gi", M.issues, { desc = "List GitHub Issues" })
	vim.keymap.set("n", "<leader>op", M.pull_requests, { desc = "List GitHub Pull Requests" })
	vim.keymap.set("n", "<leader>on", M.notifications, { desc = "List GitHub Notifications" })
	vim.keymap.set("n", "<leader>os", M.search, { desc = "Search GitHub Issues and PRs" })
	vim.keymap.set("n", "<leader>gI", M.create_issue, { desc = "Create GitHub Issue" })
	vim.keymap.set("n", "<leader>oP", M.create_pull_request, { desc = "Create GitHub Pull Request" })
end

return M
