local M = {}

local max_preview_lines = 300

local function file_lines(path)
	local buf = vim.fn.bufnr(path)
	if buf > 0 and vim.api.nvim_buf_is_loaded(buf) then
		return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	end
	if vim.fn.filereadable(path) == 1 then
		return vim.fn.readfile(path)
	end
	return { "" }
end

local function edit_groups(edit)
	local groups = {}
	for uri, edits in pairs(edit.changes or {}) do
		groups[uri] = groups[uri] or {}
		vim.list_extend(groups[uri], edits)
	end
	local operations = {}
	for _, change in ipairs(edit.documentChanges or {}) do
		if change.textDocument and change.edits then
			local uri = change.textDocument.uri
			groups[uri] = groups[uri] or {}
			vim.list_extend(groups[uri], change.edits)
		elseif change.kind then
			operations[#operations + 1] = change
		end
	end
	return groups, operations
end

local function preview_edit(edit, client)
	local groups, operations = edit_groups(edit)
	local output = {}
	local uris = vim.tbl_keys(groups)
	table.sort(uris)
	for _, uri in ipairs(uris) do
		local edits = groups[uri]
		local ok, path = pcall(vim.uri_to_fname, uri)
		if ok then
			local original = file_lines(path)
			local scratch = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_buf_set_lines(scratch, 0, -1, false, original)
			local applied, error_message = pcall(vim.lsp.util.apply_text_edits, edits, scratch, client.offset_encoding)
			local updated = applied and vim.api.nvim_buf_get_lines(scratch, 0, -1, false) or original
			vim.api.nvim_buf_delete(scratch, { force = true })
			output[#output + 1] = "--- " .. path
			if applied then
				local diff = vim.diff(table.concat(original, "\n"), table.concat(updated, "\n"), {
					result_type = "unified",
					algorithm = "histogram",
				})
				if diff and diff ~= "" then
					vim.list_extend(output, vim.split(diff, "\n", { trimempty = true }))
				else
					output[#output + 1] = "(no text changes)"
				end
			else
				output[#output + 1] = "(preview failed: " .. tostring(error_message) .. ")"
			end
		end
	end
	for _, operation in ipairs(operations) do
		output[#output + 1] = string.format("%s %s", operation.kind, operation.uri or operation.oldUri or "")
	end
	if #output == 0 then
		output[1] = "This action has no immediate workspace edit."
	end
	if #output > max_preview_lines then
		output[max_preview_lines] = "… preview truncated …"
		for index = #output, max_preview_lines + 1, -1 do
			output[index] = nil
		end
	end
	return output
end

local function preview_action(entry)
	local action = entry.action
	local lines = {
		"Action: " .. (action.title or action.command or "Untitled"),
		"Server: " .. entry.client.name,
	}
	if action.kind then
		lines[#lines + 1] = "Kind: " .. action.kind
	end
	if action.isPreferred then
		lines[#lines + 1] = "Preferred action"
	end
	lines[#lines + 1] = ""
	if action.edit then
		vim.list_extend(lines, preview_edit(action.edit, entry.client))
	elseif action.command then
		lines[#lines + 1] = "Command: "
			.. tostring(type(action.command) == "table" and action.command.command or action.command)
		lines[#lines + 1] = "No workspace edit was provided."
	elseif action.data then
		lines[#lines + 1] = "The server will resolve this action when you apply it."
	else
		lines[#lines + 1] = "This action has no previewable text edit."
	end
	return lines
end

local function close_picker(picker)
	if picker.group then
		pcall(vim.api.nvim_del_augroup_by_id, picker.group)
		picker.group = nil
	end
	for _, win in ipairs({ picker.list_win, picker.preview_win }) do
		if win and vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end
	for _, buf in ipairs({ picker.list_buf, picker.preview_buf }) do
		if buf and vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_buf_delete(buf, { force = true })
		end
	end
end

local function update_preview(picker)
	if not vim.api.nvim_win_is_valid(picker.list_win) or not vim.api.nvim_buf_is_valid(picker.preview_buf) then
		return
	end
	local row = vim.api.nvim_win_get_cursor(picker.list_win)[1]
	local entry = picker.actions[row]
	if not entry then
		return
	end
	local lines = preview_action(entry)
	vim.bo[picker.preview_buf].modifiable = true
	vim.api.nvim_buf_set_lines(picker.preview_buf, 0, -1, false, lines)
	vim.bo[picker.preview_buf].modifiable = false
	vim.api.nvim_win_set_cursor(picker.preview_win, { 1, 0 })
end

local function execute_action(entry, buf, changedtick, picker)
	close_picker(picker)
	if not vim.api.nvim_buf_is_valid(buf) or vim.api.nvim_buf_get_changedtick(buf) ~= changedtick then
		vim.notify("Buffer changed; code action was not applied", vim.log.levels.WARN, { title = "NazoVim Actions" })
		return
	end
	local client = vim.lsp.get_client_by_id(entry.client.id)
	if not client then
		vim.notify("Language server disconnected before the action was applied", vim.log.levels.WARN, {
			title = "NazoVim Actions",
		})
		return
	end
	local function apply(action)
		if action.edit then
			local ok, err = pcall(vim.lsp.util.apply_workspace_edit, action.edit, client.offset_encoding)
			if not ok then
				vim.notify(tostring(err), vim.log.levels.ERROR, { title = "NazoVim Actions" })
				return
			end
		end
		if action.command then
			local command = type(action.command) == "table" and action.command or action
			local ok, err = pcall(client.exec_cmd, client, command, { bufnr = buf }, function(request_error)
				if request_error then
					vim.notify(request_error.message or "Code action command failed", vim.log.levels.ERROR, {
						title = "NazoVim Actions",
					})
				end
			end)
			if not ok then
				vim.notify(tostring(err), vim.log.levels.ERROR, { title = "NazoVim Actions" })
			end
		end
	end
	local action = entry.action
	if action.data and not action.edit and not action.command and client:supports_method("codeAction/resolve") then
		client:request("codeAction/resolve", action, function(err, resolved)
			vim.schedule(function()
				if err or not resolved then
					vim.notify(err and err.message or "Could not resolve code action", vim.log.levels.ERROR, {
						title = "NazoVim Actions",
					})
					return
				end
				if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_changedtick(buf) == changedtick then
					apply(resolved)
				else
					vim.notify("Buffer changed while resolving the action", vim.log.levels.WARN, {
						title = "NazoVim Actions",
					})
				end
			end)
		end, buf)
	elseif action.data and not action.edit and not action.command then
		vim.notify("This server cannot resolve the selected code action", vim.log.levels.ERROR, {
			title = "NazoVim Actions",
		})
	else
		apply(action)
	end
end

local function open_picker(actions, buf, changedtick)
	if vim.o.columns < 48 or vim.o.lines < 15 then
		vim.ui.select(actions, {
			prompt = "Code action:",
			format_item = function(entry)
				return entry.action.title or entry.action.command or "Untitled action"
			end,
		}, function(entry)
			if entry then
				execute_action(entry, buf, changedtick, { list_win = nil, preview_win = nil })
			end
		end)
		return
	end

	table.sort(actions, function(a, b)
		if a.action.isPreferred ~= b.action.isPreferred then
			return a.action.isPreferred == true
		end
		return (a.action.title or "") < (b.action.title or "")
	end)
	local width = math.min(112, vim.o.columns - 6)
	local height = math.min(vim.o.lines - 6, math.max(10, math.floor((vim.o.lines - 6) * 0.72)))
	local list_height = math.max(4, math.min(#actions, math.floor(height * 0.34)))
	local preview_height = height - list_height - 2
	local left = math.floor((vim.o.columns - width) / 2)
	local top = math.floor((vim.o.lines - height - 2) / 2)
	local list_buf = vim.api.nvim_create_buf(false, true)
	local preview_buf = vim.api.nvim_create_buf(false, true)
	local picker = {
		actions = actions,
		list_buf = list_buf,
		preview_buf = preview_buf,
		group = vim.api.nvim_create_augroup("NazoActionPreview", { clear = true }),
	}
	local list_lines = {}
	for _, entry in ipairs(actions) do
		local preferred = entry.action.isPreferred and "★ " or "  "
		list_lines[#list_lines + 1] = preferred .. (entry.action.title or entry.action.command or "Untitled action")
	end
	vim.api.nvim_buf_set_lines(list_buf, 0, -1, false, list_lines)
	vim.bo[list_buf].bufhidden = "wipe"
	vim.bo[list_buf].modifiable = false
	vim.bo[preview_buf].buftype = "nofile"
	vim.bo[preview_buf].bufhidden = "wipe"
	vim.bo[preview_buf].filetype = "diff"
	vim.bo[preview_buf].modifiable = false
	picker.list_win = vim.api.nvim_open_win(list_buf, true, {
		relative = "editor",
		row = top,
		col = left,
		width = width,
		height = list_height,
		style = "minimal",
		border = "rounded",
		title = " Code Actions ",
	})
	picker.preview_win = vim.api.nvim_open_win(preview_buf, false, {
		relative = "editor",
		row = top + list_height + 2,
		col = left,
		width = width,
		height = preview_height,
		style = "minimal",
		border = "rounded",
		title = " Preview ",
	})
	vim.wo[picker.list_win].cursorline = true
	vim.wo[picker.preview_win].wrap = false
	vim.api.nvim_create_autocmd("CursorMoved", {
		group = picker.group,
		buffer = list_buf,
		callback = function()
			update_preview(picker)
		end,
	})
	local function map(keys, callback, desc)
		vim.keymap.set("n", keys, callback, { buffer = list_buf, nowait = true, silent = true, desc = desc })
	end
	map("q", function()
		close_picker(picker)
	end, "Close code actions")
	map("<Esc>", function()
		close_picker(picker)
	end, "Close code actions")
	map("<CR>", function()
		local row = vim.api.nvim_win_get_cursor(picker.list_win)[1]
		local entry = picker.actions[row]
		if entry then
			execute_action(entry, buf, changedtick, picker)
		end
	end, "Apply code action")
	update_preview(picker)
end

---Request, preview, and apply code actions with an independent floating UI.
function M.code_actions()
	local buf = vim.api.nvim_get_current_buf()
	local win = vim.api.nvim_get_current_win()
	local cursor = vim.api.nvim_win_get_cursor(win)
	local row = cursor[1] - 1
	local changedtick = vim.api.nvim_buf_get_changedtick(buf)
	local clients = vim.lsp.get_clients({ bufnr = buf, method = "textDocument/codeAction" })
	if #clients == 0 then
		vim.notify("No language server provides code actions for this buffer", vim.log.levels.INFO, {
			title = "NazoVim Actions",
		})
		return
	end
	local diagnostics = {}
	for _, diagnostic in ipairs(vim.diagnostic.get(buf, { lnum = row })) do
		local lsp_diagnostic = diagnostic.user_data and diagnostic.user_data.lsp
		if lsp_diagnostic then
			diagnostics[#diagnostics + 1] = lsp_diagnostic
		end
	end
	vim.lsp.buf_request_all(buf, "textDocument/codeAction", function(client)
		local params = vim.lsp.util.make_range_params(win, client.offset_encoding)
		params.context = {
			diagnostics = diagnostics,
			triggerKind = vim.lsp.protocol.CodeActionTriggerKind.Invoked,
		}
		return params
	end, function(results)
		vim.schedule(function()
			if
				not vim.api.nvim_buf_is_valid(buf)
				or vim.api.nvim_get_current_buf() ~= buf
				or vim.api.nvim_buf_get_changedtick(buf) ~= changedtick
			then
				return
			end
			local actions = {}
			for client_id, response in pairs(results) do
				if not response.err then
					local client = vim.lsp.get_client_by_id(client_id)
					if type(response.result) == "table" then
						for _, action in ipairs(response.result) do
							if client and not action.disabled then
								actions[#actions + 1] = { action = action, client = client }
							end
						end
					end
				end
			end
			if #actions == 0 then
				vim.notify("No code actions available", vim.log.levels.INFO, { title = "NazoVim Actions" })
				return
			end
			open_picker(actions, buf, changedtick)
		end)
	end)
end

---Register the independent preview picker keymap.
function M.setup()
	vim.keymap.set("n", "<leader>ca", M.code_actions, { desc = "Code Action (preview)" })
end

return M
