local M = {}

local function repository_root()
	return vim.fs.root(0, ".git") or vim.fn.getcwd()
end

local function run(arguments, callback)
	if vim.fn.executable("gh") ~= 1 then
		vim.notify("GitHub CLI (gh) is required", vim.log.levels.ERROR, { title = "NazoVim GitHub Issues" })
		return
	end
	vim.system(vim.list_extend({ "gh" }, arguments), { cwd = repository_root(), text = true }, function(result)
		vim.schedule(function()
			if result.code ~= 0 then
				local message = vim.trim(result.stderr or "")
				vim.notify(message ~= "" and message or "GitHub CLI command failed", vim.log.levels.ERROR, {
					title = "NazoVim GitHub Issues",
				})
				return
			end
			callback(result.stdout or "")
		end)
	end)
end

local function decode(output)
	local ok, value = pcall(vim.json.decode, output)
	if not ok or type(value) ~= "table" then
		vim.notify("Could not decode GitHub response", vim.log.levels.ERROR, { title = "NazoVim GitHub Issues" })
		return nil
	end
	return value
end

local function graphql(query, variables, callback)
	local arguments = { "api", "graphql", "-f", "query=" .. query }
	for key, value in pairs(variables) do
		arguments[#arguments + 1] = type(value) == "number" and "-F" or "-f"
		arguments[#arguments + 1] = key .. "=" .. tostring(value)
	end
	run(arguments, function(output)
		local response = decode(output)
		if not response then
			return
		end
		if response.errors and response.errors[1] then
			vim.notify(response.errors[1].message or "GitHub GraphQL request failed", vim.log.levels.ERROR, {
				title = "NazoVim GitHub Issues",
			})
			return
		end
		if type(response.data) ~= "table" then
			vim.notify("GitHub GraphQL returned no data", vim.log.levels.ERROR, { title = "NazoVim GitHub Issues" })
			return
		end
		callback(response.data)
	end)
end

local function issue_details(issue, callback)
	local owner, name, number = tostring(issue.url):match("^https?://[^/]+/([^/]+)/([^/]+)/issues/(%d+)")
	if not owner then
		vim.notify("Could not identify this issue's repository", vim.log.levels.ERROR, {
			title = "NazoVim GitHub Issues",
		})
		return
	end
	local query = [[query($owner:String!, $name:String!, $number:Int!) {
  repository(owner:$owner, name:$name) {
    issue(number:$number) {
      id title isPinned viewerCanPin viewerCanSubscribe viewerSubscription
    }
  }
}]]
	graphql(query, { owner = owner, name = name, number = tonumber(number) }, function(data)
		local result = data.repository and data.repository.issue
		if not result then
			vim.notify("Issue not found", vim.log.levels.ERROR, { title = "NazoVim GitHub Issues" })
			return
		end
		callback(result)
	end)
end

local function toggle_pin(issue)
	if not issue.viewerCanPin then
		vim.notify("You cannot pin this issue", vim.log.levels.WARN, { title = "NazoVim GitHub Issues" })
		return
	end
	local mutation = issue.isPinned and [[mutation($id:ID!) { unpinIssue(input:{issueId:$id}) { issue { id } } }]]
		or [[mutation($id:ID!) { pinIssue(input:{issueId:$id}) { issue { id } } }]]
	graphql(mutation, { id = issue.id }, function()
		vim.notify(issue.isPinned and "Issue unpinned" or "Issue pinned", vim.log.levels.INFO, {
			title = "NazoVim GitHub Issues",
		})
	end)
end

local function change_subscription(issue)
	if not issue.viewerCanSubscribe then
		vim.notify("You cannot change this issue subscription", vim.log.levels.WARN, {
			title = "NazoVim GitHub Issues",
		})
		return
	end
	local choices = {
		{ label = "Subscribe", value = "SUBSCRIBED" },
		{ label = "Unsubscribe", value = "UNSUBSCRIBED" },
		{ label = "Ignore", value = "IGNORED" },
	}
	vim.ui.select(choices, {
		prompt = "Issue notifications · currently " .. tostring(issue.viewerSubscription or "UNSUBSCRIBED"),
		format_item = function(choice)
			return choice.label
		end,
	}, function(choice)
		if not choice then
			return
		end
		local mutation = [[mutation($id:ID!, $state:SubscriptionState!) {
  updateSubscription(input:{subscribableId:$id, state:$state}) { subscribable { id } }
}]]
		graphql(mutation, { id = issue.id, state = choice.value }, function()
			vim.notify("Issue subscription updated", vim.log.levels.INFO, { title = "NazoVim GitHub Issues" })
		end)
	end)
end

local function develop_branch(issue)
	local number = tostring(issue.number)
	vim.ui.input({ prompt = "Branch name for issue #" .. number .. ": ", default = "issue-" .. number }, function(name)
		name = vim.trim(name or "")
		if name == "" then
			return
		end
		local modes = {
			{ label = "Create and check out", args = { "--checkout" } },
			{ label = "Create without checking out", args = {} },
		}
		vim.ui.select(modes, {
			prompt = "Linked branch for issue #" .. number,
			format_item = function(mode)
				return mode.label
			end,
		}, function(mode)
			if not mode then
				return
			end
			local arguments = { "issue", "develop", number, "--name", name }
			vim.list_extend(arguments, mode.args)
			run(arguments, function(output)
				local message = vim.trim(output)
				vim.notify(message ~= "" and message or "Linked branch created", vim.log.levels.INFO, {
					title = "NazoVim GitHub Issues",
				})
			end)
		end)
	end)
end

local function choose_action(issue)
	local actions = {
		{
			label = issue.isPinned and "Unpin issue" or "Pin issue",
			run = function()
				toggle_pin(issue)
			end,
		},
		{
			label = "Change notification subscription",
			run = function()
				change_subscription(issue)
			end,
		},
		{
			label = "Create linked branch",
			run = function()
				develop_branch(issue)
			end,
		},
	}
	vim.ui.select(actions, {
		prompt = string.format("Issue #%s · %s", issue.number, issue.title),
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
	run({ "issue", "list", "--state", "all", "--limit", "100", "--json", "number,title,url" }, function(output)
		local issues = decode(output)
		if not issues then
			return
		end
		if #issues == 0 then
			vim.notify("No issues found", vim.log.levels.INFO, { title = "NazoVim GitHub Issues" })
			return
		end
		vim.ui.select(issues, {
			prompt = "Manage GitHub issue pin and subscription",
			format_item = function(issue)
				return string.format("#%s %s", issue.number, issue.title)
			end,
		}, function(issue)
			if issue then
				issue_details(issue, choose_action)
			end
		end)
	end)
end

function M.setup()
	vim.api.nvim_create_user_command("NazoGitHubIssueExtras", M.open, {
		desc = "Manage GitHub issue pin and subscription",
	})
	vim.keymap.set("n", "<leader>oI", M.open, { desc = "Manage GitHub Issue Extras" })
end

return M
