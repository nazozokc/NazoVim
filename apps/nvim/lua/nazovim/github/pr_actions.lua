local M = {}

local function repository_root()
	return vim.fs.root(0, ".git") or vim.fn.getcwd()
end

local function run(arguments, callback, show_nonzero)
	if vim.fn.executable("gh") ~= 1 then
		vim.notify("GitHub CLI (gh) is required", vim.log.levels.ERROR, { title = "NazoVim GitHub PR" })
		return
	end
	vim.system(vim.list_extend({ "gh" }, arguments), { cwd = repository_root(), text = true }, function(result)
		vim.schedule(function()
			if result.code ~= 0 and not show_nonzero then
				local message = vim.trim(result.stderr or "")
				vim.notify(message ~= "" and message or "GitHub pull request command failed", vim.log.levels.ERROR, {
					title = "NazoVim GitHub PR",
				})
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

local function show_checks(item)
	run({
		"pr",
		"checks",
		tostring(item.url or item.number),
		"--json",
		"bucket,name,state,workflow,description,link",
	}, function(result)
		local checks = decode(result.stdout or "")
		local lines = { "# Checks for PR #" .. item.number .. " " .. item.title, "" }
		local links = {}
		if checks then
			for _, check in ipairs(checks) do
				local label =
					string.format("%s · %s · %s", check.name or "check", check.bucket or "unknown", check.state or "")
				if check.workflow and check.workflow ~= "" then
					label = label .. " · " .. check.workflow
				end
				lines[#lines + 1] = label
				links[#lines] = check.link
				if check.description and check.description ~= "" then
					lines[#lines + 1] = "  " .. check.description
					links[#lines] = nil
				end
			end
		elseif vim.trim(result.stdout or "") ~= "" then
			vim.list_extend(lines, vim.split(vim.trim(result.stdout), "\n", { plain = true }))
		else
			lines[#lines + 1] = vim.trim(result.stderr or "No checks reported")
		end
		if checks and #checks == 0 then
			lines[#lines + 1] = ""
			lines[#lines + 1] = "No check runs were returned."
		end
		lines[#lines + 1] = ""
		lines[#lines + 1] = "Exit status: " .. tostring(result.code) .. " · gx open selected check · q close"
		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_name(buf, "NazoGitHub://checks/" .. item.number .. "/" .. buf)
		vim.bo[buf].buftype = "nofile"
		vim.bo[buf].bufhidden = "wipe"
		vim.bo[buf].filetype = "markdown"
		vim.bo[buf].swapfile = false
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		vim.cmd("botright split")
		vim.api.nvim_win_set_buf(0, buf)
		vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, desc = "Close checks view" })
		vim.keymap.set("n", "gx", function()
			local line = vim.api.nvim_win_get_cursor(0)[1]
			if links[line] then
				vim.ui.open(links[line])
			end
		end, { buffer = buf, desc = "Open check run" })
	end, true)
end

local function confirm(prompt, callback)
	vim.ui.select({ "Confirm" }, { prompt = prompt }, function(choice)
		if choice then
			callback()
		end
	end)
end

local function merge(item)
	local strategies = {
		{ label = "Squash", flag = "--squash" },
		{ label = "Merge commit", flag = "--merge" },
		{ label = "Rebase", flag = "--rebase" },
	}
	vim.ui.select(strategies, {
		prompt = "Merge PR #" .. item.number .. " · " .. item.title,
		format_item = function(strategy)
			return strategy.label
		end,
	}, function(strategy)
		if not strategy then
			return
		end
		confirm("Merge PR #" .. item.number .. " using " .. strategy.label .. "?", function()
			run({ "pr", "merge", tostring(item.url or item.number), strategy.flag }, function(result)
				vim.notify(vim.trim(result.stdout or "Pull request merged"), vim.log.levels.INFO, {
					title = "NazoVim GitHub PR",
				})
			end)
		end)
	end)
end

local function checkout(item)
	confirm("Check out PR #" .. item.number .. " into the current repository?", function()
		run({ "pr", "checkout", tostring(item.url or item.number) }, function(result)
			vim.notify(vim.trim(result.stdout or "Pull request checked out"), vim.log.levels.INFO, {
				title = "NazoVim GitHub PR",
			})
		end)
	end)
end

local function set_draft(item)
	local action = item.isDraft and "mark ready for review" or "convert to draft"
	local arguments = { "pr", "ready", tostring(item.url or item.number) }
	if not item.isDraft then
		arguments[#arguments + 1] = "--undo"
	end
	confirm("" .. action .. " for PR #" .. item.number .. "?", function()
		run(arguments, function(result)
			vim.notify(vim.trim(result.stdout or "Pull request state updated"), vim.log.levels.INFO, {
				title = "NazoVim GitHub PR",
			})
		end)
	end)
end

local function update_branch(item)
	local methods = {
		{ label = "Merge base branch into PR branch", args = {} },
		{ label = "Rebase PR branch onto base", args = { "--rebase" } },
	}
	vim.ui.select(methods, {
		prompt = "Update PR #" .. item.number .. " branch",
		format_item = function(method)
			return method.label
		end,
	}, function(method)
		if method then
			confirm(method.label .. "?", function()
				local arguments = { "pr", "update-branch", tostring(item.url or item.number) }
				vim.list_extend(arguments, method.args)
				run(arguments, function(result)
					vim.notify(vim.trim(result.stdout or "Pull request branch updated"), vim.log.levels.INFO, {
						title = "NazoVim GitHub PR",
					})
				end)
			end)
		end
	end)
end

local function choose_action(item)
	local actions = {
		{
			label = "View checks",
			run = function()
				show_checks(item)
			end,
		},
		{
			label = "Check out branch",
			run = function()
				checkout(item)
			end,
		},
		{
			label = item.isDraft and "Mark ready for review" or "Convert to draft",
			run = function()
				set_draft(item)
			end,
		},
		{
			label = "Update branch from base",
			run = function()
				update_branch(item)
			end,
		},
		{
			label = "Merge pull request",
			run = function()
				merge(item)
			end,
		},
	}
	vim.ui.select(actions, {
		prompt = "PR #" .. item.number .. " · " .. item.title,
		format_item = function(action)
			return action.label
		end,
	}, function(action)
		if action then
			action.run()
		end
	end)
end

function M.open()
	run(
		{ "pr", "list", "--limit", "100", "--json", "number,title,url,isDraft,reviewDecision,mergeStateStatus" },
		function(result)
			local items = decode(result.stdout or "")
			if not items then
				vim.notify("Could not decode pull request list", vim.log.levels.ERROR, { title = "NazoVim GitHub PR" })
				return
			end
			if #items == 0 then
				vim.notify("No open pull requests", vim.log.levels.INFO, { title = "NazoVim GitHub PR" })
				return
			end
			vim.ui.select(items, {
				prompt = "GitHub pull request actions",
				format_item = function(item)
					local draft = item.isDraft and "draft · " or ""
					return string.format(
						"#%s %s%s · %s",
						item.number,
						draft,
						item.title,
						item.reviewDecision or "pending"
					)
				end,
			}, function(item)
				if item then
					choose_action(item)
				end
			end)
		end
	)
end

function M.setup()
	vim.api.nvim_create_user_command("NazoGitHubPRActions", M.open, { desc = "Run GitHub pull request actions" })
	vim.keymap.set("n", "<leader>oA", M.open, { desc = "GitHub Pull Request Actions" })
end

return M
