local M = {}

local function repository_root()
	return vim.fs.root(0, ".git") or vim.fn.getcwd()
end

local function run(arguments, callback)
	if vim.fn.executable("gh") ~= 1 then
		vim.notify("GitHub CLI (gh) is required", vim.log.levels.ERROR, { title = "NazoVim GitHub Review" })
		return
	end
	vim.system(vim.list_extend({ "gh" }, arguments), { cwd = repository_root(), text = true }, function(result)
		vim.schedule(function()
			if result.code ~= 0 then
				local message = vim.trim(result.stderr or "")
				vim.notify(message ~= "" and message or "GitHub review failed", vim.log.levels.ERROR, {
					title = "NazoVim GitHub Review",
				})
				return
			end
			callback(result.stdout or "")
		end)
	end)
end

local function graphql(item, query, variables, callback)
	local owner, repository, number = tostring(item.url):match("^https?://[^/]+/([^/]+)/([^/]+)/pull/(%d+)")
	if not owner then
		vim.notify("Could not identify the repository and pull request", vim.log.levels.ERROR, {
			title = "NazoVim GitHub Review",
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
		local ok, response = pcall(vim.json.decode, output)
		if not ok or type(response) ~= "table" then
			vim.notify("Could not decode GitHub GraphQL response", vim.log.levels.ERROR, {
				title = "NazoVim GitHub Review",
			})
			return
		end
		if response.errors and response.errors[1] then
			vim.notify(response.errors[1].message or "GitHub GraphQL request failed", vim.log.levels.ERROR, {
				title = "NazoVim GitHub Review",
			})
			return
		end
		if type(response.data) ~= "table" then
			vim.notify("GitHub GraphQL returned no data", vim.log.levels.ERROR, {
				title = "NazoVim GitHub Review",
			})
			return
		end
		callback(response.data)
	end)
end

local function open_text_editor(name, submit, allow_empty)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(buf, name .. "/" .. buf)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = "markdown"
	vim.bo[buf].swapfile = false
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "" })
	vim.cmd("botright split")
	vim.api.nvim_win_set_buf(0, buf)
	vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, desc = "Cancel GitHub comment" })
	local function send()
		local body = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
		if not allow_empty and vim.trim(body) == "" then
			vim.notify("A comment is required", vim.log.levels.ERROR, { title = "NazoVim GitHub Review" })
			return
		end
		submit(body, buf)
	end
	vim.keymap.set({ "n", "i" }, "<C-s>", function()
		if vim.api.nvim_get_mode().mode:sub(1, 1) == "i" then
			vim.cmd("stopinsert")
		end
		send()
	end, { buffer = buf, desc = "Submit GitHub comment" })
	vim.cmd("startinsert")
	vim.notify("Write a reply, then press <C-s> · q cancels", vim.log.levels.INFO, {
		title = "NazoVim GitHub Review",
	})
end

local function load_threads(item, callback)
	local function fetch(after, accumulated, request_id)
		local query = [[query($owner:String!, $name:String!, $number:Int!, $after:String) {
  repository(owner:$owner, name:$name) {
    pullRequest(number:$number) {
      reviewThreads(first:100, after:$after) {
        nodes {
          id path line startLine diffSide isResolved isOutdated viewerCanReply viewerCanResolve viewerCanUnresolve
          comments(first:50) { nodes { id body createdAt url author { login } } }
        }
        pageInfo { hasNextPage endCursor }
      }
    }
  }
	  }]]
		graphql(item, query, after and { after = after } or nil, function(data)
			local request = data.repository and data.repository.pullRequest
			if not request then
				vim.notify("Pull request was not found", vim.log.levels.ERROR, { title = "NazoVim GitHub Review" })
				return
			end
			request_id = request_id or request.id
			vim.list_extend(accumulated, request.reviewThreads.nodes or {})
			local page_info = request.reviewThreads.pageInfo or {}
			if page_info.hasNextPage and page_info.endCursor then
				fetch(page_info.endCursor, accumulated, request_id)
			else
				callback(accumulated, request_id)
			end
		end)
	end
	fetch(nil, {}, nil)
end

local function show_thread(item, thread, existing_buf)
	local comments = thread.comments and thread.comments.nodes or {}
	local lines = {
		string.format(
			"# %s:%s%s",
			thread.path,
			tostring(thread.startLine or thread.line or "file"),
			thread.isResolved and " · resolved" or ""
		),
		thread.isOutdated and "Outdated: yes" or "Outdated: no",
		"Actions: r reply · x resolve/reopen · gx GitHub · q close",
		"",
	}
	for _, comment in ipairs(comments) do
		lines[#lines + 1] = "## "
			.. ((comment.author and comment.author.login) or "unknown")
			.. " · "
			.. (comment.createdAt or "")
		lines[#lines + 1] = ""
		vim.list_extend(lines, vim.split(comment.body or "", "\n", { plain = true }))
		lines[#lines + 1] = ""
	end
	local buf = existing_buf
	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_name(buf, "NazoGitHub://thread/" .. thread.id:gsub("[^%w%-]", "_") .. "/" .. buf)
		vim.bo[buf].buftype = "nofile"
		vim.bo[buf].bufhidden = "wipe"
		vim.bo[buf].filetype = "markdown"
		vim.bo[buf].swapfile = false
		vim.cmd("botright split")
		vim.api.nvim_win_set_buf(0, buf)
	end
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, desc = "Close review thread" })
	vim.keymap.set("n", "gx", function()
		local latest = comments[#comments]
		vim.ui.open((latest and latest.url) or item.url)
	end, { buffer = buf, desc = "Open review thread on GitHub" })
	vim.keymap.set("n", "r", function()
		if not thread.viewerCanReply then
			vim.notify("You cannot reply to this thread", vim.log.levels.WARN, { title = "NazoVim GitHub Review" })
			return
		end
		local mutation = [[mutation($threadId:ID!, $body:String!) {
  addPullRequestReviewThreadReply(input:{pullRequestReviewThreadId:$threadId, body:$body}) { comment { id } }
}]]
		open_text_editor("NazoGitHub://reply/" .. thread.id:gsub("[^%w%-]", "_"), function(body, editor)
			graphql(item, mutation, { threadId = thread.id, body = body }, function()
				vim.notify("Review thread reply added", vim.log.levels.INFO, { title = "NazoVim GitHub Review" })
				if vim.api.nvim_buf_is_valid(editor) then
					vim.api.nvim_buf_delete(editor, { force = true })
				end
				load_threads(item, function(threads)
					for _, updated in ipairs(threads) do
						if updated.id == thread.id then
							show_thread(item, updated, buf)
							break
						end
					end
				end)
			end)
		end, false)
	end, { buffer = buf, desc = "Reply to review thread" })
	vim.keymap.set("n", "x", function()
		local can_change = thread.isResolved and thread.viewerCanUnresolve or thread.viewerCanResolve
		if not can_change then
			vim.notify("You cannot change this thread's resolution", vim.log.levels.WARN, {
				title = "NazoVim GitHub Review",
			})
			return
		end
		local action = thread.isResolved and "unresolve" or "resolve"
		vim.ui.select({ "Confirm " .. action }, { prompt = action .. " this review thread?" }, function(choice)
			if not choice then
				return
			end
			local mutation = action == "resolve"
					and [[mutation($threadId:ID!) { resolveReviewThread(input:{threadId:$threadId}) { thread { id } } }]]
				or [[mutation($threadId:ID!) { unresolveReviewThread(input:{threadId:$threadId}) { thread { id } } }]]
			graphql(item, mutation, { threadId = thread.id }, function()
				load_threads(item, function(threads)
					for _, updated in ipairs(threads) do
						if updated.id == thread.id then
							show_thread(item, updated, buf)
							break
						end
					end
				end)
			end)
		end)
	end, { buffer = buf, desc = "Resolve or reopen review thread" })
	return buf
end

local function choose_thread(item, threads)
	if #threads == 0 then
		vim.notify("No review threads on this pull request", vim.log.levels.INFO, { title = "NazoVim GitHub Review" })
		return
	end
	vim.ui.select(threads, {
		prompt = "Review threads · " .. item.title,
		format_item = function(thread)
			local comment = thread.comments and thread.comments.nodes and thread.comments.nodes[1]
			local state = thread.isResolved and "resolved" or (thread.isOutdated and "outdated" or "open")
			return string.format(
				"%s:%s · %s · %s",
				thread.path,
				thread.line or "file",
				state,
				comment and comment.body or ""
			)
		end,
	}, function(thread)
		if thread then
			show_thread(item, thread)
		end
	end)
end

local function add_line_comment(item, pull_request_id, location)
	local mutation = [[mutation($pullRequestId:ID!, $path:String!, $line:Int!, $side:DiffSide!,
  $body:String!, $startLine:Int, $startSide:DiffSide) {
  addPullRequestReview(input:{
    pullRequestId:$pullRequestId,
    event:COMMENT,
    threads:[{
      path:$path, line:$line, side:$side,
      startLine:$startLine, startSide:$startSide, body:$body
    }]
  }) { pullRequestReview { id state } }
}]]
	open_text_editor("NazoGitHub://line-comment/" .. item.number, function(body, editor)
		graphql(item, mutation, {
			pullRequestId = pull_request_id,
			path = location.path,
			line = location.line,
			side = location.side,
			startLine = location.startLine,
			startSide = location.startSide,
			body = body,
		}, function()
			vim.notify("Inline review comment submitted", vim.log.levels.INFO, { title = "NazoVim GitHub Review" })
			if vim.api.nvim_buf_is_valid(editor) then
				vim.api.nvim_buf_delete(editor, { force = true })
			end
			load_threads(item, function(threads)
				choose_thread(item, threads)
			end)
		end)
	end, false)
end

local function read_pull_request_id(item, callback)
	local query = [[query($owner:String!, $name:String!, $number:Int!) {
  repository(owner:$owner, name:$name) { pullRequest(number:$number) { id } }
}]]
	graphql(item, query, nil, function(data)
		local request = data.repository and data.repository.pullRequest
		if request and request.id then
			callback(request.id)
		else
			vim.notify("Could not find pull request ID", vim.log.levels.ERROR, { title = "NazoVim GitHub Review" })
		end
	end)
end

local function begin_review(item, action)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(buf, "NazoGitHub://review/" .. item.number .. "/" .. buf)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = "markdown"
	vim.bo[buf].swapfile = false
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "" })
	vim.cmd("botright split")
	vim.api.nvim_win_set_buf(0, buf)
	vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, desc = "Cancel GitHub review" })
	local function submit()
		local body = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
		if action ~= "approve" and vim.trim(body) == "" then
			vim.notify("A review comment is required", vim.log.levels.ERROR, { title = "NazoVim GitHub Review" })
			return
		end
		local arguments = { "pr", "review", tostring(item.url or item.number), "--" .. action }
		if vim.trim(body) ~= "" then
			vim.list_extend(arguments, { "--body", body })
		end
		run(arguments, function()
			vim.notify("Review submitted: " .. action:gsub("%-", " "), vim.log.levels.INFO, {
				title = "NazoVim GitHub Review",
			})
			if vim.api.nvim_buf_is_valid(buf) then
				vim.api.nvim_buf_delete(buf, { force = true })
			end
		end)
	end
	vim.keymap.set({ "n", "i" }, "<C-s>", function()
		if vim.api.nvim_get_mode().mode:sub(1, 1) == "i" then
			vim.cmd("stopinsert")
		end
		submit()
	end, { buffer = buf, desc = "Submit pull request review" })
	vim.cmd("startinsert")
	vim.notify("Write review text, then press <C-s> · q cancels", vim.log.levels.INFO, {
		title = "NazoVim GitHub Review",
	})
end

local choose_action

local function show_diff(item)
	run({ "pr", "diff", tostring(item.url or item.number), "--patch", "--color", "never" }, function(output)
		local lines = vim.split(output, "\n", { plain = true })
		local locations = {}
		local path, old_line, new_line
		for index, line in ipairs(lines) do
			if line:match("^diff %-%-git ") then
				path = nil
			end
			local old_path = line:match("^%-%-%- a/(.+)$")
			local new_path = line:match("^%+%+%+ b/(.+)$")
			if old_path then
				path = old_path
			end
			if new_path then
				path = new_path
			elseif line:match("^@@") then
				local old_start, new_start = line:match("^@@ %-(%d+)[^+]*%+(%d+)")
				old_line, new_line = tonumber(old_start), tonumber(new_start)
			elseif path and old_line and new_line then
				local marker = line:sub(1, 1)
				if marker == "+" and not line:match("^%+%+%+") then
					locations[index] = { path = path, line = new_line, side = "RIGHT" }
					new_line = new_line + 1
				elseif marker == "-" and not line:match("^%-%-%-") then
					locations[index] = { path = path, line = old_line, side = "LEFT" }
					old_line = old_line + 1
				elseif marker == " " then
					locations[index] = { path = path, line = new_line, side = "RIGHT" }
					old_line, new_line = old_line + 1, new_line + 1
				end
			end
		end
		local buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_name(buf, "NazoGitHub://diff/" .. item.number .. "/" .. buf)
		vim.bo[buf].buftype = "nofile"
		vim.bo[buf].bufhidden = "wipe"
		vim.bo[buf].filetype = "diff"
		vim.bo[buf].swapfile = false
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
		vim.cmd("botright split")
		vim.api.nvim_win_set_buf(0, buf)
		vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, desc = "Close pull request diff" })
		vim.keymap.set("n", "gx", function()
			vim.ui.open(item.url)
		end, { buffer = buf, desc = "Open pull request on GitHub" })
		vim.keymap.set("n", "r", function()
			choose_action(item)
		end, { buffer = buf, desc = "Submit pull request review" })
		vim.keymap.set("n", "t", function()
			load_threads(item, function(threads)
				choose_thread(item, threads)
			end)
		end, { buffer = buf, desc = "Browse review threads" })
		local function comment_at(location)
			if not location then
				vim.notify("Place the cursor on a changed or context line first", vim.log.levels.WARN, {
					title = "NazoVim GitHub Review",
				})
				return
			end
			read_pull_request_id(item, function(pull_request_id)
				add_line_comment(item, pull_request_id, location)
			end)
		end
		vim.keymap.set("n", "c", function()
			comment_at(locations[vim.api.nvim_win_get_cursor(0)[1]])
		end, { buffer = buf, desc = "Comment on diff line" })
		vim.keymap.set("x", "c", function()
			local start_line = vim.fn.line("v")
			local end_line = vim.fn.line(".")
			if start_line > end_line then
				start_line, end_line = end_line, start_line
			end
			local first = locations[start_line]
			local last = locations[end_line]
			if not first or not last or first.path ~= last.path or first.side ~= last.side then
				vim.notify("Select lines from one file and one diff side", vim.log.levels.WARN, {
					title = "NazoVim GitHub Review",
				})
				return
			end
			local range = vim.deepcopy(last)
			if first.line ~= last.line then
				range.startLine = first.line
				range.startSide = first.side
			end
			vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
			comment_at(range)
		end, { buffer = buf, desc = "Comment on selected diff lines" })
	end)
end

choose_action = function(item)
	local actions = {
		{ label = "View diff", value = "diff" },
		{ label = "Approve", value = "approve" },
		{ label = "Comment", value = "comment" },
		{ label = "Request changes", value = "request-changes" },
	}
	vim.ui.select(actions, {
		prompt = "Review PR #" .. item.number .. " · " .. item.title,
		format_item = function(action)
			return action.label
		end,
	}, function(action)
		if action and action.value == "diff" then
			show_diff(item)
		elseif action then
			begin_review(item, action.value)
		end
	end)
end

function M.open()
	run({ "pr", "list", "--limit", "100", "--json", "number,title,url,author,reviewDecision" }, function(output)
		local ok, items = pcall(vim.json.decode, output)
		if not ok then
			vim.notify("Could not decode pull request list", vim.log.levels.ERROR, { title = "NazoVim GitHub Review" })
			return
		end
		if #items == 0 then
			vim.notify("No open pull requests", vim.log.levels.INFO, { title = "NazoVim GitHub Review" })
			return
		end
		vim.ui.select(items, {
			prompt = "Choose a pull request to review",
			format_item = function(item)
				return string.format("#%s %s · %s", item.number, item.title, item.reviewDecision or "pending")
			end,
		}, function(item)
			if item then
				choose_action(item)
			end
		end)
	end)
end

function M.setup()
	vim.api.nvim_create_user_command("NazoGitHubReview", M.open, { desc = "Review an open GitHub pull request" })
	vim.keymap.set("n", "<leader>oR", M.open, { desc = "Review GitHub Pull Request" })
end

return M
