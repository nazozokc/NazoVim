local M = {}
local generation, previous = 0, nil
local requests = {}
local ns = vim.api.nvim_create_namespace("NazoReferences")
local groups = { "LspReferenceText", "LspReferenceRead", "LspReferenceWrite" }

local function clear()
	generation = generation + 1
	for _, request in ipairs(requests) do
		request.client:cancel_request(request.id)
	end
	requests = {}
	if previous and vim.api.nvim_buf_is_valid(previous) then
		vim.api.nvim_buf_clear_namespace(previous, ns, 0, -1)
	end
end

local function mark(buf, sr, sc, er, ec, kind)
	if sr < 0 or er >= vim.api.nvim_buf_line_count(buf) then
		return
	end
	vim.api.nvim_buf_set_extmark(
		buf,
		ns,
		sr,
		sc,
		{ end_row = er, end_col = ec, hl_group = groups[kind or 1], priority = 120, strict = false }
	)
end

local function treesitter(buf)
	if vim.api.nvim_buf_line_count(buf) > 5000 then
		return
	end
	-- The built-in locals index needs a parser and a locals query.
	local ok, locals = pcall(require, "nazovim.lib.locals")
	if not ok then
		return
	end
	local parsed, nodes = pcall(function()
		local node = vim.treesitter.get_node({ bufnr = buf })
		if not node then
			return {}
		end
		local definition, scope, kind = locals.find_definition(node, buf)
		local usages = locals.find_usages(definition, scope, buf)
		if kind then
			table.insert(usages, definition)
		end
		return usages
	end)
	if not parsed then
		return
	end -- Missing/incompatible parser: leave the buffer undecorated.
	for _, node in ipairs(nodes) do
		local sr, sc, er, ec = node:range()
		mark(buf, sr, sc, er, ec, 1)
	end
end

---Request references for the current cursor, rejecting stale asynchronous replies.
function M.update()
	clear()
	local buf, win = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
	previous = buf
	if not require("nazovim.lib.ui").normal(buf) or not vim.api.nvim_get_mode().mode:match("^[nvV\22]") then
		return
	end
	local cursor, tick, current = vim.api.nvim_win_get_cursor(win), vim.api.nvim_buf_get_changedtick(buf), generation
	local clients = vim.lsp.get_clients({ bufnr = buf, method = "textDocument/documentHighlight" })
	if #clients == 0 then
		treesitter(buf)
		return
	end
	local remaining, found = #clients, false
	local function valid()
		return current == generation
			and vim.api.nvim_buf_is_valid(buf)
			and vim.api.nvim_win_is_valid(win)
			and vim.api.nvim_get_current_buf() == buf
			and vim.api.nvim_buf_get_changedtick(buf) == tick
			and vim.deep_equal(cursor, vim.api.nvim_win_get_cursor(win))
	end
	for _, client in ipairs(clients) do
		local function reply(err, result)
			remaining = remaining - 1
			if not valid() then
				return
			end
			if not err then
				for _, reference in ipairs(result or {}) do
					local range = reference.range
					local start_line = vim.api.nvim_buf_get_lines(buf, range.start.line, range.start.line + 1, false)[1]
					local end_line = vim.api.nvim_buf_get_lines(buf, range["end"].line, range["end"].line + 1, false)[1]
					if start_line and end_line then
						local sc = vim.str_byteindex(start_line, client.offset_encoding, range.start.character, false)
						local ec = vim.str_byteindex(end_line, client.offset_encoding, range["end"].character, false)
						mark(buf, range.start.line, sc, range["end"].line, ec, reference.kind)
						found = true
					end
				end
			end
			if remaining == 0 and not found then
				treesitter(buf)
			end
		end
		local accepted, id = client:request(
			"textDocument/documentHighlight",
			vim.lsp.util.make_position_params(win, client.offset_encoding),
			reply,
			buf
		)
		if accepted then
			requests[#requests + 1] = { client = client, id = id }
		else
			reply(true)
		end
	end
end

local function jump(direction)
	local marks = vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {})
	if #marks == 0 then
		return
	end
	local cursor = vim.api.nvim_win_get_cursor(0)
	local chosen = direction > 0 and marks[1] or marks[#marks]
	for i = direction > 0 and 1 or #marks, direction > 0 and #marks or 1, direction do
		local item = marks[i]
		local delta = item[2] == cursor[1] - 1 and item[3] - cursor[2] or item[2] - (cursor[1] - 1)
		if delta * direction > 0 then
			chosen = item
			break
		end
	end
	vim.cmd("normal! m'")
	vim.api.nvim_win_set_cursor(0, { chosen[2] + 1, chosen[3] })
end

---Enable debounced LSP/Treesitter highlights and reference navigation.
function M.setup()
	local group = vim.api.nvim_create_augroup("NazoReferences", { clear = true })
	local update = require("nazovim.lib.ui").throttle(120, M.update)
	vim.api.nvim_create_autocmd(
		{ "CursorMoved", "BufEnter", "InsertLeave", "LspAttach" },
		{ group = group, callback = update }
	)
	vim.api.nvim_create_autocmd(
		{ "CursorMoved", "InsertEnter", "BufLeave", "TextChanged", "TextChangedI", "LspDetach" },
		{ group = group, callback = clear }
	)
	vim.keymap.set("n", "<M-n>", function()
		jump(1)
	end, { desc = "Next reference" })
	vim.keymap.set("n", "<M-p>", function()
		jump(-1)
	end, { desc = "Previous reference" })
	vim.keymap.set({ "x", "o" }, "<M-i>", function()
		local cursor = vim.api.nvim_win_get_cursor(0)
		for _, item in ipairs(vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, { details = true })) do
			local ending = item[4]
			if
				item[2] == cursor[1] - 1
				and item[3] <= cursor[2]
				and ending.end_row == item[2]
				and cursor[2] < ending.end_col
			then
				vim.cmd.normal({ args = { "\27" }, bang = true })
				vim.api.nvim_win_set_cursor(0, { item[2] + 1, item[3] })
				vim.cmd("normal! v")
				local line = vim.api.nvim_get_current_line():sub(1, ending.end_col)
				local last = vim.fn.byteidx(line, vim.fn.strchars(line) - 1)
				vim.api.nvim_win_set_cursor(0, { ending.end_row + 1, last })
				return
			end
		end
	end, { desc = "Reference text object" })
	update()
end

return M
