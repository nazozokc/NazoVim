local M = {}

local namespace = vim.api.nvim_create_namespace("NazoIncrementalSelection")
local states = {}

local function clear(buf)
	vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
	states[buf] = nil
end

local function current_node(buf)
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row, col = cursor[1] - 1, cursor[2]
	local ok, node = pcall(vim.treesitter.get_node, { bufnr = buf, pos = { row, col } })
	if (not ok or not node) and col > 0 then
		ok, node = pcall(vim.treesitter.get_node, { bufnr = buf, pos = { row, col - 1 } })
	end
	return ok and node or nil
end

local function store_node(buf, state, node)
	if not node then
		return false
	end
	local start_row, start_col, end_row, end_col = node:range()
	state.start_id = vim.api.nvim_buf_set_extmark(buf, namespace, start_row, start_col, { right_gravity = false })
	state.end_id = vim.api.nvim_buf_set_extmark(buf, namespace, end_row, end_col, { right_gravity = true })
	return true
end

local function select_marks(buf, state)
	local start = vim.api.nvim_buf_get_extmark_by_id(buf, namespace, state.start_id, {})
	local finish = vim.api.nvim_buf_get_extmark_by_id(buf, namespace, state.end_id, {})
	if #start == 0 or #finish == 0 or start[1] == finish[1] and start[2] == finish[2] then
		return false
	end
	vim.api.nvim_win_set_cursor(0, { start[1] + 1, start[2] })
	vim.cmd.normal({ args = { "v" }, bang = true })
	local end_row, end_col = finish[1], finish[2]
	if end_col == 0 and end_row > 0 then
		end_row = end_row - 1
		local line = vim.api.nvim_buf_get_lines(buf, end_row, end_row + 1, false)[1] or ""
		end_col = math.max(0, vim.fn.byteidx(line, math.max(0, vim.fn.strchars(line) - 1)))
	else
		local line = vim.api.nvim_buf_get_lines(buf, end_row, end_row + 1, false)[1] or ""
		local char_index = vim.fn.charidx(line, math.min(end_col, #line))
		end_col = math.max(0, vim.fn.byteidx(line, math.max(0, char_index - 1)))
	end
	vim.api.nvim_win_set_cursor(0, { end_row + 1, end_col })
	return true
end

---Begin selection at the smallest syntax node under the cursor.
function M.start()
	local buf = vim.api.nvim_get_current_buf()
	if vim.bo[buf].buftype ~= "" or vim.api.nvim_buf_line_count(buf) > 10000 then
		return false
	end
	local node = current_node(buf)
	if not node then
		return false
	end
	clear(buf)
	local state = { nodes = { node } }
	states[buf] = state
	store_node(buf, state, node)
	return select_marks(buf, state)
end

---Expand the active selection to its parent syntax node.
function M.expand()
	local buf = vim.api.nvim_get_current_buf()
	local state = states[buf]
	if not state then
		return M.start()
	end
	local parent = state.nodes[#state.nodes]:parent()
	if not parent or not store_node(buf, state, parent) then
		return false
	end
	state.nodes[#state.nodes + 1] = parent
	return select_marks(buf, state)
end

---Shrink an active selection to its preceding syntax node.
function M.shrink()
	local buf = vim.api.nvim_get_current_buf()
	local state = states[buf]
	if not state or #state.nodes <= 1 then
		return false
	end
	table.remove(state.nodes)
	store_node(buf, state, state.nodes[#state.nodes])
	return select_marks(buf, state)
end

---Clear selection tracking and return to characterwise Normal mode.
function M.stop()
	local buf = vim.api.nvim_get_current_buf()
	clear(buf)
	if vim.api.nvim_get_mode().mode == "v" then
		vim.cmd.normal({ args = { "<Esc>" }, bang = true })
	end
end

function M.setup()
	local group = vim.api.nvim_create_augroup("NazoIncrementalSelection", { clear = true })
	vim.api.nvim_create_autocmd("BufWipeout", {
		group = group,
		callback = function(args)
			states[args.buf] = nil
		end,
	})
	vim.keymap.set("n", "gnn", M.start, { desc = "Start syntax selection" })
	vim.keymap.set("x", "grn", M.expand, { desc = "Expand syntax selection" })
	vim.keymap.set("x", "grm", M.shrink, { desc = "Shrink syntax selection" })
	vim.keymap.set("x", "grq", M.stop, { desc = "Stop syntax selection" })
end

return M
