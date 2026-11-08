local M = {}

local title = "NazoVim LSP"
local max_depth = 4
local max_nodes = 300

local labels = {
	incomingCalls = "Incoming calls",
	outgoingCalls = "Outgoing calls",
}

local function notify(message, level)
	vim.notify(message, level or vim.log.levels.INFO, { title = title })
end

---Convert a `CallHierarchyItem` into a quickfix entry.
---The column is left at the line start so no offset encoding is needed.
---@param node table
---@param depth integer
---@return table
function M.item(node, depth)
	local range = node.selectionRange or node.range
	return {
		filename = vim.uri_to_fname(node.uri),
		lnum = (range and range.start.line or 0) + 1,
		col = 1,
		text = string.rep("  ", depth) .. (node.name or "?"),
		valid = 1,
	}
end

---Write the collected calls into the quickfix list.
---@param state table
function M.finish(state)
	if state.done then
		return
	end
	state.done = true
	if #state.items == 0 then
		notify("No " .. (labels[state.direction] or "call"):lower() .. " found")
		return
	end
	require("nazovim.ui.lists").set("NazoVim " .. (labels[state.direction] or "Calls"), state.items)
end

---Request one hierarchy level and recurse into the results.
---@param client table
---@param node table
---@param depth integer
---@param direction string
---@param state table
function M.walk(client, node, depth, direction, state)
	if state.done or depth > max_depth or state.count >= max_nodes then
		return
	end
	state.pending = state.pending + 1
	local accepted = client:request("callHierarchy/" .. direction, { item = node }, function(err, result)
		vim.schedule(function()
			state.pending = state.pending - 1
			if not err and result then
				for _, call in ipairs(result) do
					local child = direction == "incomingCalls" and call.from or call.to
					if child and state.count < max_nodes then
						state.count = state.count + 1
						state.items[#state.items + 1] = M.item(child, depth)
						M.walk(client, child, depth + 1, direction, state)
					end
				end
			end
			if state.pending == 0 then
				M.finish(state)
			end
		end)
	end)
	if not accepted then
		vim.schedule(function()
			state.pending = state.pending - 1
			if state.pending == 0 then
				M.finish(state)
			end
		end)
	end
end

---Show the incoming or outgoing calls of the symbol under the cursor.
---@param direction "incomingCalls"|"outgoingCalls"
function M.run(direction)
	local buf = vim.api.nvim_get_current_buf()
	if #vim.lsp.get_clients({ bufnr = buf, method = "textDocument/prepareCallHierarchy" }) == 0 then
		notify("No language server provides call hierarchies for this buffer", vim.log.levels.WARN)
		return
	end
	local state = { items = {}, count = 0, pending = 0, done = false, direction = direction }
	vim.lsp.buf_request_all(buf, "textDocument/prepareCallHierarchy", function(client)
		return vim.lsp.util.make_position_params(0, client.offset_encoding)
	end, function(results)
		vim.schedule(function()
			local roots = 0
			for client_id, response in pairs(results) do
				local client = vim.lsp.get_client_by_id(client_id)
				if client and not response.err and response.result then
					for _, node in ipairs(response.result) do
						roots = roots + 1
						M.walk(client, node, 0, direction, state)
					end
				end
			end
			if roots == 0 then
				state.done = true
				notify("No call hierarchy item under the cursor")
			elseif state.pending == 0 then
				M.finish(state)
			end
		end)
	end)
end

---Register the commands for call hierarchy listing.
function M.setup()
	vim.api.nvim_create_user_command("NazoLspIncomingCalls", function()
		M.run("incomingCalls")
	end, { desc = "List incoming calls" })
	vim.api.nvim_create_user_command("NazoLspOutgoingCalls", function()
		M.run("outgoingCalls")
	end, { desc = "List outgoing calls" })
end

return M
