local M = {}

local title = "NazoVim GitHub Projects"

local function repository_root()
	return vim.fs.root(0, ".git") or vim.fn.getcwd()
end

local function run(arguments, callback)
	if vim.fn.executable("gh") ~= 1 then
		vim.notify("GitHub CLI (gh) is required", vim.log.levels.ERROR, { title = title })
		return
	end
	vim.system(vim.list_extend({ "gh" }, arguments), { cwd = repository_root(), text = true }, function(result)
		vim.schedule(function()
			if result.code ~= 0 then
				local message = vim.trim(result.stderr or "")
				if message:find("missing required scopes", 1, true) then
					message = message .. "\nRun: gh auth refresh -s project"
				end
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

local function repository_owner()
	local result = vim.system({ "git", "remote", "get-url", "origin" }, { cwd = repository_root(), text = true }):wait()
	if result.code ~= 0 then
		return nil
	end
	local url = vim.trim(result.stdout or "")
	return url:match("^https?://[^/]+/([^/]+)/") or url:match("^git@[^:]+:([^/]+)/")
end

---Value of a project item field, matched case-insensitively.
local function field_value(item, field)
	if not field then
		return nil
	end
	local wanted = field.name:lower()
	for key, value in pairs(item) do
		if type(key) == "string" and key:lower() == wanted and type(value) == "string" then
			return value
		end
	end
	return nil
end

local function item_label(item)
	local content = item.content or {}
	local kind = content.type == "PullRequest" and "PR" or content.type
	local text = content.title or item.title or ""
	if content.number then
		return string.format("%s #%s %s", kind or "Item", content.number, text)
	end
	if kind == "DraftIssue" then
		return "Draft: " .. text
	end
	return text
end

local function open_view(name, lines)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(buf, "NazoGitHub://" .. name .. "/" .. buf)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = "markdown"
	vim.bo[buf].swapfile = false
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.cmd("botright split")
	vim.api.nvim_win_set_buf(0, buf)
	vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, desc = "Close project view" })
	return buf
end

local function confirm(prompt, callback)
	vim.ui.select({ "Confirm" }, { prompt = prompt }, function(choice)
		if choice then
			callback()
		end
	end)
end

local function archive_item(project, item, refresh)
	confirm("Archive this project item?", function()
		run(
			{ "project", "item-archive", tostring(project.number), "--owner", project.owner, "--id", item.id },
			function()
				vim.notify("Project item archived", vim.log.levels.INFO, { title = title })
				refresh()
			end
		)
	end)
end

local function move_item(project, field, item, refresh)
	local options = field.options or {}
	vim.ui.select(options, {
		prompt = "Move item to " .. field.name,
		format_item = function(option)
			return option.name
		end,
	}, function(option)
		if not option then
			return
		end
		local arguments = {
			"project",
			"item-edit",
			tostring(project.number),
			"--owner",
			project.owner,
			"--field",
			field.name,
			"--value",
			option.name,
		}
		local url = item.content and item.content.url
		if url then
			vim.list_extend(arguments, { "--url", url })
		else
			vim.list_extend(arguments, { "--id", item.id })
		end
		run(arguments, function()
			vim.notify("Project item moved to " .. option.name, vim.log.levels.INFO, { title = title })
			refresh()
		end)
	end)
end

local function choose_item_action(project, field, item, refresh)
	local actions = {}
	if field then
		actions[#actions + 1] = {
			label = "Move to another " .. field.name .. " value",
			run = function()
				move_item(project, field, item, refresh)
			end,
		}
	end
	actions[#actions + 1] = {
		label = "Open on GitHub",
		run = function()
			vim.ui.open(item.content.url)
		end,
	}
	actions[#actions + 1] = {
		label = "Archive item",
		run = function()
			archive_item(project, item, refresh)
		end,
	}
	vim.ui.select(actions, {
		prompt = item_label(item),
		format_item = function(action)
			return action.label
		end,
	}, function(action)
		if action then
			action.run()
		end
	end)
end

local function show_items(project, field, existing)
	local state = { lookup = {} }
	local buf = existing and vim.api.nvim_buf_is_valid(existing) and existing or nil
	if not buf then
		buf = open_view("project/" .. project.number, {})
		vim.keymap.set("n", "<CR>", function()
			local item = state.lookup[vim.api.nvim_win_get_cursor(0)[1]]
			if item then
				choose_item_action(project, field, item, function()
					show_items(project, field, buf)
				end)
			end
		end, { buffer = buf, desc = "Manage project item" })
		vim.keymap.set("n", "gx", function()
			local item = state.lookup[vim.api.nvim_win_get_cursor(0)[1]]
			if item and item.content and item.content.url then
				vim.ui.open(item.content.url)
			end
		end, { buffer = buf, desc = "Open project item" })
	end
	local arguments = {
		"project",
		"item-list",
		tostring(project.number),
		"--owner",
		project.owner,
		"--format",
		"json",
		"--limit",
		"100",
	}
	if field then
		vim.list_extend(arguments, { "--field", field.name })
	end
	run(arguments, function(result)
		local data = decode(result.stdout or "")
		local items = data and data.items or {}
		local lines = {
			string.format(
				"# %s · items%s",
				project.title or ("Project " .. project.number),
				field and (" · " .. field.name) or ""
			),
			"Actions: <CR> item actions · gx open on GitHub · q close",
			"",
		}
		local lookup = {}
		for _, item in ipairs(items) do
			lines[#lines + 1] = string.format("%-12s %s", field_value(item, field) or "-", item_label(item))
			lookup[#lines] = item
		end
		if #items == 0 then
			lines[#lines + 1] = "No items were returned."
		end
		state.lookup = lookup
		vim.bo[buf].modifiable = true
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		vim.bo[buf].modifiable = false
	end)
end

local function add_item(project, refresh)
	local groups = { pr = {}, issue = {} }
	local pending = 2
	local function finish()
		pending = pending - 1
		if pending > 0 then
			return
		end
		local candidates = {}
		vim.list_extend(candidates, groups.pr)
		vim.list_extend(candidates, groups.issue)
		if #candidates == 0 then
			vim.notify("No open issues or pull requests", vim.log.levels.INFO, { title = title })
			return
		end
		vim.ui.select(candidates, {
			prompt = "Add to " .. (project.title or "project"),
			format_item = function(candidate)
				return candidate.label
			end,
		}, function(candidate)
			if not candidate then
				return
			end
			run(
				{ "project", "item-add", tostring(project.number), "--owner", project.owner, "--url", candidate.url },
				function()
					vim.notify("Added to project", vim.log.levels.INFO, { title = title })
					refresh()
				end
			)
		end)
	end
	local function collect(kind)
		run({ kind, "list", "--limit", "100", "--json", "number,title,url" }, function(result)
			local entries = decode(result.stdout or "") or {}
			for _, entry in ipairs(entries) do
				groups[kind][#groups[kind] + 1] = {
					label = string.format("%s #%s %s", kind == "pr" and "PR" or "Issue", entry.number, entry.title),
					url = entry.url,
				}
			end
			finish()
		end)
	end
	collect("pr")
	collect("issue")
end

local function choose_project_action(project, fields)
	local single = {}
	for _, field in ipairs(fields) do
		if field.type == "ProjectV2SingleSelectField" then
			single[#single + 1] = field
		end
	end
	for index, field in ipairs(single) do
		if field.name == "Status" then
			single[1], single[index] = field, single[1]
			break
		end
	end
	local actions = {
		{
			label = "Items",
			run = function()
				show_items(project, single[1])
			end,
		},
		{
			label = "Add issue or pull request",
			run = function()
				add_item(project, function()
					show_items(project, single[1])
				end)
			end,
		},
		{
			label = "Open in browser",
			run = function()
				run({ "project", "view", tostring(project.number), "--owner", project.owner, "--web" }, function() end)
			end,
		},
	}
	vim.ui.select(actions, {
		prompt = string.format("Project #%s · %s", project.number, project.title or ""),
		format_item = function(action)
			return action.label
		end,
	}, function(action)
		if action then
			action.run()
		end
	end)
end

local function load_project(project)
	run({
		"project",
		"field-list",
		tostring(project.number),
		"--owner",
		project.owner,
		"--format",
		"json",
		"--limit",
		"50",
	}, function(result)
		local data = decode(result.stdout or "")
		choose_project_action(project, data and data.fields or {})
	end)
end

local function choose_project(owner, fallback)
	run({ "project", "list", "--owner", owner, "--format", "json", "--limit", "50" }, function(result)
		local data = decode(result.stdout or "")
		local projects = data and data.projects or {}
		if #projects == 0 and not fallback and owner ~= "@me" then
			return choose_project("@me", true)
		end
		if #projects == 0 then
			vim.notify("No projects found for " .. owner, vim.log.levels.INFO, { title = title })
			return
		end
		for _, project in ipairs(projects) do
			project.owner = owner
		end
		vim.ui.select(projects, {
			prompt = "GitHub projects for " .. owner,
			format_item = function(project)
				return string.format(
					"#%s %s%s",
					project.number,
					project.title or "",
					project.closed and " · closed" or ""
				)
			end,
		}, function(project)
			if project then
				load_project(project)
			end
		end)
	end)
end

function M.open()
	local owner = repository_owner()
	if not owner then
		vim.notify("Could not detect the repository owner", vim.log.levels.ERROR, { title = title })
		return
	end
	choose_project(owner)
end

function M.setup()
	vim.api.nvim_create_user_command("NazoGitHubProjects", M.open, {
		desc = "Browse GitHub projects and manage their items",
	})
	vim.keymap.set("n", "<leader>oB", M.open, { desc = "GitHub Projects" })
end

return M
