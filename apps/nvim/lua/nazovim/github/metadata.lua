local M = {}

local reactions = {
	{ label = "👍 Thumbs up", value = "THUMBS_UP" },
	{ label = "👎 Thumbs down", value = "THUMBS_DOWN" },
	{ label = "😄 Laugh", value = "LAUGH" },
	{ label = "🎉 Hooray", value = "HOORAY" },
	{ label = "😕 Confused", value = "CONFUSED" },
	{ label = "❤️ Heart", value = "HEART" },
	{ label = "🚀 Rocket", value = "ROCKET" },
	{ label = "👀 Eyes", value = "EYES" },
}

local function repository_root()
	return vim.fs.root(0, ".git") or vim.fn.getcwd()
end

local function run(arguments, callback)
	if vim.fn.executable("gh") ~= 1 then
		vim.notify("GitHub CLI (gh) is required", vim.log.levels.ERROR, { title = "NazoVim GitHub Metadata" })
		return
	end
	vim.system(vim.list_extend({ "gh" }, arguments), { cwd = repository_root(), text = true }, function(result)
		vim.schedule(function()
			if result.code ~= 0 then
				local message = vim.trim(result.stderr or "")
				vim.notify(message ~= "" and message or "GitHub metadata update failed", vim.log.levels.ERROR, {
					title = "NazoVim GitHub Metadata",
				})
				return
			end
			if callback then
				callback(result.stdout or "")
			end
		end)
	end)
end

local function decode(output)
	local ok, value = pcall(vim.json.decode, output)
	if not ok or type(value) ~= "table" then
		vim.notify("Could not decode GitHub response", vim.log.levels.ERROR, { title = "NazoVim GitHub Metadata" })
		return nil
	end
	return value
end

local function graphql(item, query, variables, callback)
	local owner, repository, number = tostring(item.url):match("^https?://[^/]+/([^/]+)/([^/]+)/issues/(%d+)")
	if not owner then
		owner, repository, number = tostring(item.url):match("^https?://[^/]+/([^/]+)/([^/]+)/pull/(%d+)")
	end
	if not owner then
		vim.notify("Could not identify the repository and issue", vim.log.levels.ERROR, {
			title = "NazoVim GitHub Metadata",
		})
		return
	end
	local arguments = {
		"api",
		"graphql",
		"-f",
		"query=" .. query,
		"-F",
		"owner=" .. owner,
		"-F",
		"name=" .. repository,
		"-F",
		"number=" .. number,
	}
	for key, value in pairs(variables or {}) do
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
				title = "NazoVim GitHub Metadata",
			})
			return
		end
		if type(response.data) ~= "table" then
			vim.notify("GitHub GraphQL returned no data", vim.log.levels.ERROR, {
				title = "NazoVim GitHub Metadata",
			})
			return
		end
		callback(response.data)
	end)
end

local function gh_kind(kind)
	return kind == "issue" and "issue" or "pr"
end

local function item_field(item, key)
	return item[key] or {}
end

local function mutate_cli(item, kind, flag, value)
	local arguments = { gh_kind(kind), "edit", tostring(item.url or item.number), flag }
	if value then
		arguments[#arguments + 1] = value
	end
	run(arguments, function()
		vim.notify("GitHub " .. flag:gsub("%-", " ") .. " updated", vim.log.levels.INFO, {
			title = "NazoVim GitHub Metadata",
		})
	end)
end

local function change_milestone(item, kind, add)
	if not add then
		mutate_cli(item, kind, "--remove-milestone")
		return
	end
	vim.ui.input({ prompt = "Milestone title: " }, function(title)
		if title and vim.trim(title) ~= "" then
			mutate_cli(item, kind, "--milestone", vim.trim(title))
		end
	end)
end

local function change_reviewer(item, add)
	vim.ui.input(
		{ prompt = (add and "Request review from" or "Remove review request for") .. " login: " },
		function(login)
			if login and vim.trim(login) ~= "" then
				mutate_cli(item, "pr", add and "--add-reviewer" or "--remove-reviewer", vim.trim(login))
			end
		end
	)
end

local function change_project(item, kind, add)
	vim.ui.input({ prompt = "GitHub project title: " }, function(title)
		if title and vim.trim(title) ~= "" then
			mutate_cli(item, kind, add and "--add-project" or "--remove-project", vim.trim(title))
		end
	end)
end

local function change_label(item, kind, add)
	local current = {}
	for _, label in ipairs(item_field(item, "labels")) do
		current[#current + 1] = label.name or tostring(label)
	end
	local function choose_label(names)
		if add then
			local present = {}
			for _, name in ipairs(current) do
				present[name] = true
			end
			names = vim.tbl_filter(function(name)
				return not present[name]
			end, names)
		else
			names = current
		end
		if #names == 0 then
			vim.notify(add and "No labels available to add" or "This item has no labels", vim.log.levels.INFO, {
				title = "NazoVim GitHub Metadata",
			})
			return
		end
		vim.ui.select(names, { prompt = add and "Add label" or "Remove label" }, function(name)
			if name then
				mutate_cli(item, kind, add and "--add-label" or "--remove-label", name)
			end
		end)
	end
	if add then
		run({ "label", "list", "--limit", "100", "--json", "name" }, function(output)
			local labels = decode(output)
			if not labels then
				return
			end
			local names = {}
			for _, label in ipairs(labels) do
				names[#names + 1] = label.name
			end
			choose_label(names)
		end)
	else
		choose_label(current)
	end
end

local function change_assignee(item, kind, add)
	local current = {}
	for _, assignee in ipairs(item_field(item, "assignees")) do
		current[#current + 1] = assignee.login or tostring(assignee)
	end
	if not add then
		if #current == 0 then
			vim.notify("This item has no assignees", vim.log.levels.INFO, { title = "NazoVim GitHub Metadata" })
			return
		end
		vim.ui.select(current, { prompt = "Remove assignee" }, function(login)
			if login then
				mutate_cli(item, kind, "--remove-assignee", login)
			end
		end)
		return
	end
	vim.ui.input({ prompt = "GitHub login to assign: " }, function(login)
		if login and vim.trim(login) ~= "" then
			mutate_cli(item, kind, "--add-assignee", vim.trim(login))
		end
	end)
end

local function toggle_reaction(item, kind)
	local subject = kind == "issue" and "issue" or "pullRequest"
	local query = string.format(
		[[query($owner:String!, $name:String!, $number:Int!, $content:ReactionContent!) {
  repository(owner:$owner, name:$name) {
    %s(number:$number) { id reactions(first:1, content:$content) { viewerHasReacted } }
  }
}]],
		subject
	)
	vim.ui.select(reactions, {
		prompt = "Toggle reaction",
		format_item = function(reaction)
			return reaction.label
		end,
	}, function(reaction)
		if not reaction then
			return
		end
		graphql(item, query, { content = reaction.value }, function(data)
			local entry = data.repository and data.repository[subject]
			if not entry then
				vim.notify("Could not load the GitHub item", vim.log.levels.ERROR, {
					title = "NazoVim GitHub Metadata",
				})
				return
			end
			local group = entry.reactions
			local remove = group and group.viewerHasReacted
			local action = remove and "removeReaction" or "addReaction"
			local mutation = string.format(
				[[mutation($subjectId:ID!, $content:ReactionContent!) {
  %s(input:{subjectId:$subjectId, content:$content}) { subject { id } }
}]],
				action
			)
			graphql(item, mutation, { subjectId = entry.id, content = reaction.value }, function()
				vim.notify((remove and "Removed " or "Added ") .. reaction.label, vim.log.levels.INFO, {
					title = "NazoVim GitHub Metadata",
				})
			end)
		end)
	end)
end

local function choose_action(item, kind)
	local actions = {
		{
			label = "Add label",
			run = function()
				change_label(item, kind, true)
			end,
		},
		{
			label = "Remove label",
			run = function()
				change_label(item, kind, false)
			end,
		},
		{
			label = "Add assignee",
			run = function()
				change_assignee(item, kind, true)
			end,
		},
		{
			label = "Remove assignee",
			run = function()
				change_assignee(item, kind, false)
			end,
		},
		{
			label = "Set milestone",
			run = function()
				change_milestone(item, kind, true)
			end,
		},
		{
			label = "Remove milestone",
			run = function()
				change_milestone(item, kind, false)
			end,
		},
		{
			label = "Add to project",
			run = function()
				change_project(item, kind, true)
			end,
		},
		{
			label = "Remove from project",
			run = function()
				change_project(item, kind, false)
			end,
		},
		{
			label = "Toggle reaction",
			run = function()
				toggle_reaction(item, kind)
			end,
		},
	}
	if kind == "pr" then
		table.insert(actions, 5, {
			label = "Request reviewer",
			run = function()
				change_reviewer(item, true)
			end,
		})
		table.insert(actions, 6, {
			label = "Remove reviewer request",
			run = function()
				change_reviewer(item, false)
			end,
		})
	end
	vim.ui.select(actions, {
		prompt = string.format("%s #%s · %s", kind == "issue" and "Issue" or "PR", item.number, item.title),
		format_item = function(action)
			return action.label
		end,
	}, function(action)
		if action then
			action.run()
		end
	end)
end

local function choose_item(kind)
	local subcommand = gh_kind(kind)
	run({
		subcommand,
		"list",
		"--state",
		"all",
		"--limit",
		"100",
		"--json",
		"number,title,url,labels,assignees,milestone",
	}, function(output)
		local items = decode(output)
		if not items then
			return
		end
		if #items == 0 then
			vim.notify("No issues or pull requests found", vim.log.levels.INFO, { title = "NazoVim GitHub Metadata" })
			return
		end
		vim.ui.select(items, {
			prompt = kind == "issue" and "Choose an issue" or "Choose a pull request",
			format_item = function(item)
				local milestone = item.milestone and (" · " .. item.milestone.title) or ""
				return string.format("#%s %s%s", item.number, item.title, milestone)
			end,
		}, function(item)
			if item then
				choose_action(item, kind)
			end
		end)
	end)
end

function M.open()
	vim.ui.select({ "Issue", "Pull request" }, { prompt = "Choose GitHub item type" }, function(choice)
		if choice then
			choose_item(choice == "Issue" and "issue" or "pr")
		end
	end)
end

function M.setup()
	vim.api.nvim_create_user_command(
		"NazoGitHubMetadata",
		M.open,
		{ desc = "Manage GitHub labels, assignees, and reactions" }
	)
	vim.keymap.set("n", "<leader>om", M.open, { desc = "Manage GitHub Metadata" })
end

return M
