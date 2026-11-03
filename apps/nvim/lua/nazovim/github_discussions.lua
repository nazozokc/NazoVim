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

local function run(arguments, callback)
	if vim.fn.executable("gh") ~= 1 then
		vim.notify("GitHub CLI (gh) is required", vim.log.levels.ERROR, { title = "NazoVim Discussions" })
		return
	end
	local cwd = vim.fs.root(0, ".git") or vim.fn.getcwd()
	vim.system(vim.list_extend({ "gh" }, arguments), { cwd = cwd, text = true }, function(result)
		vim.schedule(function()
			if result.code ~= 0 then
				local message = vim.trim(result.stderr or "")
				vim.notify(message ~= "" and message or "GitHub CLI command failed", vim.log.levels.ERROR, {
					title = "NazoVim Discussions",
				})
				return
			end
			callback(result.stdout or "")
		end)
	end)
end

local function decode(output)
	local ok, value = pcall(vim.json.decode, output)
	if not ok then
		vim.notify("Could not decode GitHub response: " .. tostring(value), vim.log.levels.ERROR, {
			title = "NazoVim Discussions",
		})
		return nil
	end
	return value
end

local function graphql(query, variables, callback)
	local arguments = { "api", "graphql", "-f", "query=" .. query }
	for key, value in pairs(variables) do
		arguments[#arguments + 1] = type(value) == "number" and "-F" or "-f"
		arguments[#arguments + 1] = key .. "=" .. value
	end
	run(arguments, function(output)
		local response = decode(output)
		if not response then
			return
		end
		if response.errors and response.errors[1] then
			vim.notify(response.errors[1].message or "GitHub GraphQL request failed", vim.log.levels.ERROR, {
				title = "NazoVim Discussions",
			})
			return
		end
		if type(response.data) ~= "table" then
			vim.notify("GitHub GraphQL returned no data", vim.log.levels.ERROR, {
				title = "NazoVim Discussions",
			})
			return
		end
		callback(response.data)
	end)
end

local function toggle_reaction(subject_id, can_react, on_done)
	if not can_react then
		vim.notify("You cannot react to this discussion", vim.log.levels.WARN, { title = "NazoVim Discussions" })
		return
	end
	vim.ui.select(reactions, {
		prompt = "Toggle reaction",
		format_item = function(reaction)
			return reaction.label
		end,
	}, function(reaction)
		if not reaction then
			return
		end
		local query = [[query($id:ID!, $content:ReactionContent!) {
  node(id:$id) { ... on Reactable { reactions(first:1, content:$content) { viewerHasReacted } } }
}]]
		graphql(query, { id = subject_id, content = reaction.value }, function(data)
			local node = data.node
			if not node then
				vim.notify("Could not load the discussion reaction", vim.log.levels.ERROR, {
					title = "NazoVim Discussions",
				})
				return
			end
			local remove = node.reactions and node.reactions.viewerHasReacted
			local mutation = string.format(
				[[mutation($id:ID!, $content:ReactionContent!) {
  %s(input:{subjectId:$id, content:$content}) { subject { id } }
}]],
				remove and "removeReaction" or "addReaction"
			)
			graphql(mutation, { id = subject_id, content = reaction.value }, function()
				vim.notify((remove and "Removed " or "Added ") .. reaction.label, vim.log.levels.INFO, {
					title = "NazoVim Discussions",
				})
				if on_done then
					on_done()
				end
			end)
		end)
	end)
end

local function with_repository(callback)
	run({ "repo", "view", "--json", "nameWithOwner" }, function(output)
		local repository = decode(output)
		local owner, name
		if repository and repository.nameWithOwner then
			owner, name = repository.nameWithOwner:match("^([^/]+)/(.+)$")
		end
		if not owner or not name then
			vim.notify("Could not determine the current GitHub repository", vim.log.levels.ERROR, {
				title = "NazoVim Discussions",
			})
			return
		end
		callback(owner, name)
	end)
end

local function show_document(name, lines, url, actions, existing_buf)
	local expanded_lines = {}
	for _, line in ipairs(lines) do
		for _, part in ipairs(vim.split(line, "\n", { plain = true })) do
			expanded_lines[#expanded_lines + 1] = part
		end
	end
	local created = not existing_buf or not vim.api.nvim_buf_is_valid(existing_buf)
	local buf = created and vim.api.nvim_create_buf(false, true) or existing_buf
	if created then
		vim.api.nvim_buf_set_name(buf, name .. "/" .. buf)
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
	if vim.api.nvim_get_current_buf() == buf then
		vim.api.nvim_win_set_cursor(0, { 1, 0 })
	end
	vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, desc = "Close discussion" })
	vim.keymap.set("n", "gx", function()
		if url and url ~= "" then
			vim.ui.open(url)
		end
	end, { buffer = buf, desc = "Open discussion on GitHub" })
	for key, action in pairs(actions or {}) do
		vim.keymap.set("n", key, action, { buffer = buf })
	end
	return buf
end

local function open_composer(name, title, body, submit)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(buf, name .. "/" .. buf)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = "markdown"
	vim.bo[buf].swapfile = false
	local lines = { title or "", "" }
	if body and body ~= "" then
		vim.list_extend(lines, vim.split(body, "\n", { plain = true }))
	end
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.cmd("botright split")
	vim.api.nvim_win_set_buf(0, buf)
	vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, desc = "Cancel discussion edit" })
	local function save()
		local content = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		local next_title = vim.trim(content[1] or "")
		if next_title == "" then
			vim.notify("A title is required", vim.log.levels.ERROR, { title = "NazoVim Discussions" })
			return
		end
		local description = {}
		for index = 2, #content do
			description[#description + 1] = content[index]
		end
		if description[1] == "" then
			table.remove(description, 1)
		end
		submit(next_title, table.concat(description, "\n"), buf)
	end
	vim.keymap.set({ "n", "i" }, "<C-s>", function()
		if vim.api.nvim_get_mode().mode:sub(1, 1) == "i" then
			vim.cmd("stopinsert")
		end
		save()
	end, { buffer = buf, desc = "Save discussion" })
	vim.notify("First line: title · remaining lines: body · <C-s> save · q cancel", vim.log.levels.INFO, {
		title = "NazoVim Discussions",
	})
end

local function open_body_editor(name, submit, initial_body)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(buf, name .. "/" .. buf)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = "markdown"
	vim.bo[buf].swapfile = false
	vim.api.nvim_buf_set_lines(
		buf,
		0,
		-1,
		false,
		initial_body and initial_body ~= "" and vim.split(initial_body, "\n", { plain = true }) or { "" }
	)
	vim.cmd("botright split")
	vim.api.nvim_win_set_buf(0, buf)
	vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, desc = "Cancel discussion reply" })
	local function send()
		local body = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
		if vim.trim(body) == "" then
			vim.notify("A reply is required", vim.log.levels.ERROR, { title = "NazoVim Discussions" })
			return
		end
		submit(body, buf)
	end
	vim.keymap.set({ "n", "i" }, "<C-s>", function()
		if vim.api.nvim_get_mode().mode:sub(1, 1) == "i" then
			vim.cmd("stopinsert")
		end
		send()
	end, { buffer = buf, desc = "Submit discussion reply" })
	vim.cmd("startinsert")
	vim.notify("Write a reply, then press <C-s> · q cancels", vim.log.levels.INFO, {
		title = "NazoVim Discussions",
	})
end

local function show_discussion(owner, name, number, existing_buf)
	local query = [[
query($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    discussion(number: $number) {
      id number title body url createdAt updatedAt closed upvoteCount viewerCanClose viewerCanReopen
      viewerCanUpdate viewerCanDelete viewerCanUpvote viewerHasUpvoted viewerCanSubscribe viewerSubscription viewerCanReact
      author { login }
      category { id name }
      poll {
        id question viewerCanVote viewerHasVoted totalVoteCount
        options(first:20) { nodes { id option totalVoteCount viewerHasVoted } }
      }
      answer { id author { login } body }
      comments(first: 50) {
        nodes {
          id author { login } body createdAt isAnswer viewerCanMarkAsAnswer viewerCanUnmarkAsAnswer
          viewerCanUpdate viewerCanDelete viewerDidAuthor viewerCanUpvote viewerHasUpvoted viewerCanReact
        }
      }
    }
  }
}]]
	graphql(query, { owner = owner, name = name, number = tonumber(number) }, function(data)
		local discussion = data and data.repository and data.repository.discussion
		if not discussion then
			vim.notify("Discussion not found", vim.log.levels.INFO, { title = "NazoVim Discussions" })
			return
		end
		local lines = {
			"# Discussion #" .. discussion.number .. " " .. discussion.title,
			"",
			"Category: " .. ((discussion.category and discussion.category.name) or "unknown"),
			"Author: " .. ((discussion.author and discussion.author.login) or "unknown"),
			"State: " .. (discussion.closed and "closed" or "open"),
			"Actions: c reply · e edit · a answer · u upvote · r reaction · p poll · s subscribe · g category · m comments · x state · d delete",
			"Answer: " .. (discussion.answer and "accepted" or "none"),
			"Replies: " .. tostring(discussion.comments and #discussion.comments.nodes or 0),
			"Upvotes: " .. tostring(discussion.upvoteCount or 0),
			"Created: " .. tostring(discussion.createdAt or ""),
			"Updated: " .. tostring(discussion.updatedAt or ""),
			"URL: " .. tostring(discussion.url or ""),
			"",
			discussion.body ~= "" and discussion.body or "(no description)",
		}
		for _, comment in ipairs(discussion.comments and discussion.comments.nodes or {}) do
			lines[#lines + 1] = ""
			lines[#lines + 1] = "## "
				.. ((comment.author and comment.author.login) or "unknown")
				.. (comment.isAnswer and " · accepted answer" or "")
			lines[#lines + 1] = comment.body
		end
		if discussion.answer then
			lines[#lines + 1] = ""
			lines[#lines + 1] = "## Accepted answer"
			lines[#lines + 1] = "### " .. ((discussion.answer.author and discussion.answer.author.login) or "unknown")
			lines[#lines + 1] = discussion.answer.body
		end
		if discussion.poll then
			lines[#lines + 1] = ""
			lines[#lines + 1] = "## Poll · " .. discussion.poll.question
			lines[#lines + 1] = "Votes: " .. tostring(discussion.poll.totalVoteCount or 0)
			for _, option in ipairs(discussion.poll.options and discussion.poll.options.nodes or {}) do
				lines[#lines + 1] = string.format(
					"- %s%s · %s votes",
					option.option,
					option.viewerHasVoted and " ✓" or "",
					tostring(option.totalVoteCount or 0)
				)
			end
		end
		local doc_buf
		local function refresh()
			if doc_buf and vim.api.nvim_buf_is_valid(doc_buf) then
				show_discussion(owner, name, number, doc_buf)
			end
		end
		local function reply()
			open_body_editor("NazoGitHub://discussion-reply/" .. discussion.number, function(body, editor)
				local mutation = [[mutation($discussionId:ID!, $body:String!) {
  addDiscussionComment(input:{discussionId:$discussionId, body:$body}) { comment { id } }
}]]
				graphql(mutation, { discussionId = discussion.id, body = body }, function(response)
					if response.addDiscussionComment and response.addDiscussionComment.comment then
						vim.notify("Discussion reply added", vim.log.levels.INFO, { title = "NazoVim Discussions" })
						if vim.api.nvim_buf_is_valid(editor) then
							vim.api.nvim_buf_delete(editor, { force = true })
						end
						refresh()
					end
				end)
			end)
		end
		local function mark_answer()
			local comments = {}
			for _, comment in ipairs(discussion.comments and discussion.comments.nodes or {}) do
				if comment.isAnswer and comment.viewerCanUnmarkAsAnswer then
					comments[#comments + 1] = comment
				elseif not discussion.answer and comment.viewerCanMarkAsAnswer then
					comments[#comments + 1] = comment
				end
			end
			if #comments == 0 then
				vim.notify(
					"No comments can be marked as an answer",
					vim.log.levels.INFO,
					{ title = "NazoVim Discussions" }
				)
				return
			end
			vim.ui.select(comments, {
				prompt = discussion.answer and "Unmark or choose accepted answer" or "Choose accepted answer",
				format_item = function(comment)
					return string.format(
						"%s · %s",
						(comment.author and comment.author.login) or "unknown",
						comment.body
					)
				end,
			}, function(comment)
				if not comment then
					return
				end
				local action = comment.isAnswer and "unmarkDiscussionCommentAsAnswer" or "markDiscussionCommentAsAnswer"
				local mutation = string.format(
					[[mutation($id:ID!) {
  %s(input:{id:$id}) { discussion { id } }
}]],
					action
				)
				graphql(mutation, { id = comment.id }, function()
					vim.notify("Discussion answer updated", vim.log.levels.INFO, { title = "NazoVim Discussions" })
					refresh()
				end)
			end)
		end
		local function toggle_state()
			local closing = not discussion.closed
			if closing and not discussion.viewerCanClose or not closing and not discussion.viewerCanReopen then
				vim.notify(
					"You cannot change this discussion state",
					vim.log.levels.WARN,
					{ title = "NazoVim Discussions" }
				)
				return
			end
			local function submit(reason)
				local action = closing and "closeDiscussion" or "reopenDiscussion"
				local mutation
				if closing then
					mutation = string.format(
						[[mutation($id:ID!) {
  closeDiscussion(input:{discussionId:$id, reason:%s}) { discussion { id } }
}]],
						reason or "RESOLVED"
					)
				else
					mutation =
						[[mutation($id:ID!) { reopenDiscussion(input:{discussionId:$id}) { discussion { id } } }]]
				end
				graphql(mutation, { id = discussion.id }, function()
					vim.notify("Discussion " .. (closing and "closed" or "reopened"), vim.log.levels.INFO, {
						title = "NazoVim Discussions",
					})
					refresh()
				end)
			end
			if closing then
				local reasons = {
					{ label = "Resolved", value = "RESOLVED" },
					{ label = "Duplicate", value = "DUPLICATE" },
					{ label = "Outdated", value = "OUTDATED" },
				}
				vim.ui.select(reasons, {
					prompt = "Close reason",
					format_item = function(reason)
						return reason.label
					end,
				}, function(reason)
					if reason then
						submit(reason.value)
					end
				end)
			else
				vim.ui.select({ "Confirm reopen" }, { prompt = "Reopen discussion?" }, function(choice)
					if choice then
						submit()
					end
				end)
			end
		end
		local function toggle_upvote()
			if not discussion.viewerCanUpvote then
				vim.notify("You cannot vote on this discussion", vim.log.levels.WARN, { title = "NazoVim Discussions" })
				return
			end
			local action = discussion.viewerHasUpvoted and "removeUpvote" or "addUpvote"
			local mutation = string.format(
				[[mutation($id:ID!) {
  %s(input:{subjectId:$id}) { subject { id } }
}]],
				action
			)
			graphql(mutation, { id = discussion.id }, function()
				refresh()
			end)
		end
		local function react()
			toggle_reaction(discussion.id, discussion.viewerCanReact, refresh)
		end
		local function vote_poll()
			local poll = discussion.poll
			if not poll then
				vim.notify("This discussion has no poll", vim.log.levels.INFO, { title = "NazoVim Discussions" })
				return
			end
			if not poll.viewerCanVote then
				vim.notify("You cannot vote in this poll", vim.log.levels.WARN, { title = "NazoVim Discussions" })
				return
			end
			local options = poll.options and poll.options.nodes or {}
			vim.ui.select(options, {
				prompt = poll.question,
				format_item = function(option)
					return string.format("%s · %s votes", option.option, tostring(option.totalVoteCount or 0))
				end,
			}, function(option)
				if not option then
					return
				end
				local mutation = [[mutation($optionId:ID!) {
  addDiscussionPollVote(input:{pollOptionId:$optionId}) { pollOption { id } }
}]]
				graphql(mutation, { optionId = option.id }, function()
					vim.notify("Poll vote recorded", vim.log.levels.INFO, { title = "NazoVim Discussions" })
					refresh()
				end)
			end)
		end
		local function delete_discussion()
			if not discussion.viewerCanDelete then
				vim.notify("You cannot delete this discussion", vim.log.levels.WARN, {
					title = "NazoVim Discussions",
				})
				return
			end
			vim.ui.select({ "Confirm delete" }, {
				prompt = "Delete this discussion and all its replies?",
			}, function(choice)
				if not choice then
					return
				end
				local mutation = [[mutation($id:ID!) {
  deleteDiscussion(input:{id:$id}) { discussion { id } }
}]]
				graphql(mutation, { id = discussion.id }, function()
					vim.notify("Discussion deleted", vim.log.levels.INFO, { title = "NazoVim Discussions" })
					if doc_buf and vim.api.nvim_buf_is_valid(doc_buf) then
						vim.api.nvim_buf_delete(doc_buf, { force = true })
					end
				end)
			end)
		end
		local function toggle_subscription()
			if not discussion.viewerCanSubscribe then
				vim.notify("You cannot change this discussion subscription", vim.log.levels.WARN, {
					title = "NazoVim Discussions",
				})
				return
			end
			local choices = {
				{ label = "Subscribe", value = "SUBSCRIBED" },
				{ label = "Unsubscribe", value = "UNSUBSCRIBED" },
				{ label = "Ignore", value = "IGNORED" },
			}
			vim.ui.select(choices, {
				prompt = "Notification state · currently "
					.. tostring(discussion.viewerSubscription or "UNSUBSCRIBED"),
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
				graphql(mutation, { id = discussion.id, state = choice.value }, function()
					vim.notify(
						"Discussion subscription updated",
						vim.log.levels.INFO,
						{ title = "NazoVim Discussions" }
					)
					refresh()
				end)
			end)
		end
		local function change_category()
			if not discussion.viewerCanUpdate then
				vim.notify("You cannot change this discussion category", vim.log.levels.WARN, {
					title = "NazoVim Discussions",
				})
				return
			end
			with_repository(function(repo_owner, repo_name)
				local query = [[query($owner:String!, $name:String!) {
  repository(owner:$owner, name:$name) { discussionCategories(first:100) { nodes { id name emoji } } }
}]]
				graphql(query, { owner = repo_owner, name = repo_name }, function(data)
					local categories = data.repository
							and data.repository.discussionCategories
							and data.repository.discussionCategories.nodes
						or {}
					if #categories == 0 then
						vim.notify("No discussion categories are available", vim.log.levels.INFO, {
							title = "NazoVim Discussions",
						})
						return
					end
					vim.ui.select(categories, {
						prompt = "Move discussion to category",
						format_item = function(category)
							return (category.emoji and category.emoji .. " " or "") .. category.name
						end,
					}, function(category)
						if not category or category.id == (discussion.category and discussion.category.id) then
							return
						end
						local mutation = [[mutation($id:ID!, $categoryId:ID!) {
  updateDiscussion(input:{discussionId:$id, categoryId:$categoryId}) { discussion { id } }
}]]
						graphql(mutation, { id = discussion.id, categoryId = category.id }, function()
							vim.notify(
								"Discussion category updated",
								vim.log.levels.INFO,
								{ title = "NazoVim Discussions" }
							)
							refresh()
						end)
					end)
				end)
			end)
		end
		local function manage_comment()
			local comments = discussion.comments and discussion.comments.nodes or {}
			if #comments == 0 then
				vim.notify("This discussion has no comments", vim.log.levels.INFO, { title = "NazoVim Discussions" })
				return
			end
			vim.ui.select(comments, {
				prompt = "Choose a discussion comment",
				format_item = function(comment)
					return string.format(
						"%s · %s",
						(comment.author and comment.author.login) or "unknown",
						comment.body
					)
				end,
			}, function(comment)
				if not comment then
					return
				end
				local actions = {}
				if comment.viewerCanUpdate then
					actions[#actions + 1] = { label = "Edit comment", value = "edit" }
				end
				if comment.viewerCanDelete then
					actions[#actions + 1] = { label = "Delete comment", value = "delete" }
				end
				actions[#actions + 1] = { label = "Reply to comment", value = "reply" }
				if comment.viewerCanUpvote then
					actions[#actions + 1] = {
						label = comment.viewerHasUpvoted and "Remove upvote" or "Upvote",
						value = "upvote",
					}
				end
				if comment.viewerCanReact then
					actions[#actions + 1] = { label = "Add or remove reaction", value = "reaction" }
				end
				vim.ui.select(actions, {
					prompt = "Comment by " .. ((comment.author and comment.author.login) or "unknown"),
					format_item = function(action)
						return action.label
					end,
				}, function(action)
					if not action then
						return
					end
					if action.value == "edit" then
						open_body_editor("NazoGitHub://discussion-comment-edit", function(body, editor)
							local mutation = [[mutation($id:ID!, $body:String!) {
  updateDiscussionComment(input:{commentId:$id, body:$body}) { comment { id } }
}]]
							graphql(mutation, { id = comment.id, body = body }, function()
								if vim.api.nvim_buf_is_valid(editor) then
									vim.api.nvim_buf_delete(editor, { force = true })
								end
								refresh()
							end)
						end, comment.body)
					elseif action.value == "delete" then
						vim.ui.select(
							{ "Confirm delete" },
							{ prompt = "Delete this discussion comment?" },
							function(choice)
								if choice then
									local mutation = [[mutation($id:ID!) {
  deleteDiscussionComment(input:{id:$id}) { comment { id } }
}]]
									graphql(mutation, { id = comment.id }, function()
										refresh()
									end)
								end
							end
						)
					elseif action.value == "reply" then
						open_body_editor("NazoGitHub://discussion-comment-reply", function(body, editor)
							local mutation = [[mutation($discussionId:ID!, $replyToId:ID!, $body:String!) {
  addDiscussionComment(input:{discussionId:$discussionId, replyToId:$replyToId, body:$body}) { comment { id } }
}]]
							graphql(
								mutation,
								{ discussionId = discussion.id, replyToId = comment.id, body = body },
								function()
									if vim.api.nvim_buf_is_valid(editor) then
										vim.api.nvim_buf_delete(editor, { force = true })
									end
									refresh()
								end
							)
						end)
					elseif action.value == "upvote" then
						local mutation = comment.viewerHasUpvoted
								and [[mutation($id:ID!) { removeUpvote(input:{subjectId:$id}) { subject { id } } }]]
							or [[mutation($id:ID!) { addUpvote(input:{subjectId:$id}) { subject { id } } }]]
						graphql(mutation, { id = comment.id }, function()
							refresh()
						end)
					elseif action.value == "reaction" then
						toggle_reaction(comment.id, comment.viewerCanReact, refresh)
					end
				end)
			end)
		end
		local function edit()
			if not discussion.viewerCanUpdate then
				vim.notify("You cannot edit this discussion", vim.log.levels.WARN, { title = "NazoVim Discussions" })
				return
			end
			open_composer(
				"NazoGitHub://discussion-edit/" .. discussion.number,
				discussion.title,
				discussion.body,
				function(title, body, editor)
					local mutation = [[mutation($id:ID!, $title:String!, $body:String!) {
  updateDiscussion(input:{discussionId:$id, title:$title, body:$body}) { discussion { id } }
}]]
					graphql(mutation, { id = discussion.id, title = title, body = body }, function()
						vim.notify("Discussion updated", vim.log.levels.INFO, { title = "NazoVim Discussions" })
						if vim.api.nvim_buf_is_valid(editor) then
							vim.api.nvim_buf_delete(editor, { force = true })
						end
						refresh()
					end)
				end
			)
		end
		doc_buf = show_document(
			"NazoGitHub://discussion/" .. owner .. "/" .. name .. "/" .. discussion.number,
			lines,
			discussion.url,
			{
				c = reply,
				e = edit,
				a = mark_answer,
				x = toggle_state,
				u = toggle_upvote,
				r = react,
				p = vote_poll,
				s = toggle_subscription,
				g = change_category,
				m = manage_comment,
				d = delete_discussion,
			},
			existing_buf
		)
	end)
end

function M.list()
	with_repository(function(owner, name)
		local query = [[
query($owner: String!, $name: String!) {
  repository(owner: $owner, name: $name) {
	    discussions(first: 100, orderBy: {field: UPDATED_AT, direction: DESC}) {
	      nodes { number title url updatedAt closed author { login } category { name } comments { totalCount } }
    }
  }
}]]
		graphql(query, { owner = owner, name = name }, function(data)
			local connection = data and data.repository and data.repository.discussions
			local items = connection and connection.nodes or {}
			if #items == 0 then
				vim.notify("No repository discussions", vim.log.levels.INFO, { title = "NazoVim Discussions" })
				return
			end
			vim.ui.select(items, {
				prompt = "GitHub Discussions · " .. owner .. "/" .. name,
				format_item = function(item)
					return string.format(
						"#%s %s · %s · %s · %s replies · %s",
						item.number,
						item.title,
						item.closed and "closed" or "open",
						(item.category and item.category.name) or "uncategorized",
						tostring(item.comments and item.comments.totalCount or 0),
						(item.author and item.author.login) or "unknown"
					)
				end,
			}, function(item)
				if item then
					show_discussion(owner, name, item.number)
				end
			end)
		end)
	end)
end

function M.create()
	with_repository(function(owner, name)
		local query = [[query($owner:String!, $name:String!) {
  repository(owner:$owner, name:$name) {
    id
    discussionCategories(first:100) { nodes { id name emoji } }
  }
}]]
		graphql(query, { owner = owner, name = name }, function(data)
			local repository = data and data.repository
			local categories = repository and repository.discussionCategories and repository.discussionCategories.nodes
				or {}
			if #categories == 0 then
				vim.notify("This repository has no discussion categories", vim.log.levels.INFO, {
					title = "NazoVim Discussions",
				})
				return
			end
			vim.ui.select(categories, {
				prompt = "Choose a discussion category",
				format_item = function(category)
					return (category.emoji and category.emoji .. " " or "") .. category.name
				end,
			}, function(category)
				if not category then
					return
				end
				open_composer("NazoGitHub://discussion-create", "", "", function(title, body, editor)
					local mutation = [[mutation($repositoryId:ID!, $categoryId:ID!, $title:String!, $body:String!) {
  createDiscussion(input:{repositoryId:$repositoryId, categoryId:$categoryId, title:$title, body:$body}) {
    discussion { number url }
  }
}]]
					graphql(mutation, {
						repositoryId = repository.id,
						categoryId = category.id,
						title = title,
						body = body,
					}, function(response)
						local created = response.createDiscussion and response.createDiscussion.discussion
						if not created then
							return
						end
						vim.notify("Discussion created: " .. tostring(created.url), vim.log.levels.INFO, {
							title = "NazoVim Discussions",
						})
						if vim.api.nvim_buf_is_valid(editor) then
							vim.api.nvim_buf_delete(editor, { force = true })
						end
						show_discussion(owner, name, created.number)
					end)
				end)
			end)
		end)
	end)
end

function M.setup()
	vim.api.nvim_create_user_command("NazoGitHubDiscussions", M.list, { desc = "List repository discussions" })
	vim.api.nvim_create_user_command(
		"NazoGitHubDiscussionCreate",
		M.create,
		{ desc = "Create a repository discussion" }
	)
	vim.keymap.set("n", "<leader>od", M.list, { desc = "List GitHub Discussions" })
	vim.keymap.set("n", "<leader>oD", M.create, { desc = "Create GitHub Discussion" })
end

return M
