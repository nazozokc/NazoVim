local M = {}

local function_types = {
	arrow_function = true,
	closure_expression = true,
	function_declaration = true,
	function_definition = true,
	function_expression = true,
	function_item = true,
	function_literal = true,
	["function"] = true,
	func_literal = true,
	lambda = true,
	lambda_expression = true,
	method = true,
	method_declaration = true,
	method_definition = true,
	singleton_method = true,
}
local class_types = {
	class_declaration = true,
	class_definition = true,
	class_specifier = true,
	enum_declaration = true,
	interface_declaration = true,
	impl_item = true,
	record_declaration = true,
	struct_declaration = true,
	struct_specifier = true,
	struct_item = true,
	trait_item = true,
}
local conditional_types = {
	case_clause = true,
	conditional_expression = true,
	if_expression = true,
	if_statement = true,
	match_expression = true,
	switch_expression = true,
	switch_statement = true,
	ternary_expression = true,
}
local loop_types = {
	do_statement = true,
	for_expression = true,
	for_in_statement = true,
	for_statement = true,
	loop_expression = true,
	repeat_statement = true,
	while_expression = true,
	while_statement = true,
}
local block_types = {
	block = true,
	class_body = true,
	compound_statement = true,
	declaration_list = true,
	statement_block = true,
	do_block = true,
}
local container_types = {
	argument_list = true,
	arguments = true,
	call_arguments = true,
	formal_parameters = true,
	parameter_list = true,
	parameters = true,
	parameters_clause = true,
}
local body_types = {
	body = true,
	block = true,
	class_body = true,
	compound_statement = true,
	declaration_list = true,
	statement_block = true,
}
local categories = {
	function_ = function_types,
	class = class_types,
	conditional = conditional_types,
	loop = loop_types,
	block = block_types,
}

local function position_before(row_a, col_a, row_b, col_b)
	return row_a < row_b or (row_a == row_b and col_a < col_b)
end

local function contains(node, row, col)
	local sr, sc, er, ec = node:range()
	return not position_before(row, col, sr, sc) and position_before(row, col, er, ec)
end

local function current_path(buf)
	local cursor = vim.api.nvim_win_get_cursor(0)
	local function get_node(col)
		return pcall(vim.treesitter.get_node, {
			bufnr = buf,
			pos = { cursor[1] - 1, col },
		})
	end
	local ok, node = get_node(cursor[2])
	if (not ok or not node) and cursor[2] > 0 then
		ok, node = get_node(cursor[2] - 1)
	end
	if not ok then
		return nil
	end
	local path = {}
	while node do
		path[#path + 1] = node
		node = node:parent()
	end
	return path
end

local function nearest(path, types)
	for _, node in ipairs(path or {}) do
		if types[node:type()] then
			return node
		end
	end
end

local function children(node)
	local result = {}
	for child in node:iter_children() do
		if child:named() then
			result[#result + 1] = child
		end
	end
	return result
end

local function range(node)
	local sr, sc, er, ec = node:range()
	return { start = { sr, sc }, finish = { er, ec } }
end

local function body_of(node)
	local candidates = {}
	for _, child in ipairs(children(node)) do
		if body_types[child:type()] then
			candidates[#candidates + 1] = child
		end
	end
	return candidates[#candidates]
end

local function content_range(node)
	local named = children(node)
	if #named == 0 then
		local row, col = node:start()
		return { start = { row, col }, finish = { row, col } }
	end
	local sr, sc = named[1]:start()
	local er, ec = named[#named]:end_()
	return { start = { sr, sc }, finish = { er, ec } }
end

local function parameter_container(path)
	for _, node in ipairs(path or {}) do
		if container_types[node:type()] then
			return node
		end
	end
end

local function parameter_child(container, row, col)
	local named = children(container)
	local nearest_child, nearest_distance
	for _, child in ipairs(named) do
		if contains(child, row, col) then
			return child, named
		end
		local sr, sc = child:start()
		local er, ec = child:end_()
		local distance = position_before(row, col, sr, sc) and ((sr - row) * 100000 + sc - col)
			or position_before(er, ec, row, col) and ((row - er) * 100000 + col - ec)
			or math.huge
		if not nearest_distance or distance < nearest_distance then
			nearest_child, nearest_distance = child, distance
		end
	end
	return nearest_child, named
end

local function object_range(category, inner, path, row, col)
	if category == "parameter" then
		local container = parameter_container(path)
		if not container then
			return
		end
		local child = parameter_child(container, row, col)
		if child then
			return range(child)
		end
		return
	end
	local node = nearest(path, categories[category])
	if not node then
		return
	end
	if inner then
		if category == "block" then
			return content_range(node)
		end
		local body = body_of(node)
		if body then
			return content_range(body)
		end
	end
	return range(node)
end

local function last_char_position(row, col)
	if col == 0 then
		if row == 0 then
			return row, 0
		end
		row = row - 1
		local line = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1] or ""
		if line == "" then
			return row, 0
		end
		return row, vim.fn.byteidx(line, vim.fn.strchars(line) - 1)
	end
	local line = vim.api.nvim_buf_get_lines(0, row, row + 1, false)[1] or ""
	local char_index = vim.fn.charidx(line, math.min(col, #line))
	return row, math.max(0, vim.fn.byteidx(line, math.max(0, char_index - 1)))
end

local function select_range(selection)
	if not selection then
		return
	end
	local sr, sc = unpack(selection.start)
	local er, ec = unpack(selection.finish)
	if sr == er and sc == ec then
		return
	end
	local mode = vim.api.nvim_get_mode().mode
	if mode == "v" or mode == "V" or mode == "\22" then
		vim.cmd.normal({ args = { "<Esc>" }, bang = true })
	end
	vim.api.nvim_win_set_cursor(0, { sr + 1, sc })
	vim.cmd.normal({ args = { "v" }, bang = true })
	local end_row, end_col = last_char_position(er, ec)
	vim.api.nvim_win_set_cursor(0, { end_row + 1, end_col })
end

---Select the syntax object or its inner body around the cursor.
function M.select(category, inner)
	local buf = vim.api.nvim_get_current_buf()
	if vim.bo[buf].buftype ~= "" or vim.api.nvim_buf_line_count(buf) > 10000 then
		return
	end
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row, col = cursor[1] - 1, cursor[2]
	local path = current_path(buf)
	select_range(object_range(category, inner, path, row, col))
end

local function collect_objects(node, category, output)
	if category == "parameter" then
		if container_types[node:type()] then
			for _, child in ipairs(children(node)) do
				output[#output + 1] = child
			end
		end
	else
		local types = categories[category]
		if types[node:type()] then
			output[#output + 1] = node
		end
	end
	for child in node:iter_children() do
		if child:named() then
			collect_objects(child, category, output)
		end
	end
end

---Move to the next or previous object boundary and add a jumplist entry.
function M.move(category, direction, boundary)
	local buf = vim.api.nvim_get_current_buf()
	if vim.bo[buf].buftype ~= "" or vim.api.nvim_buf_line_count(buf) > 10000 then
		return
	end
	local ok, parser = pcall(vim.treesitter.get_parser, buf)
	if not ok or not parser then
		return
	end
	local parsed, trees = pcall(parser.parse, parser)
	local tree = parsed and trees and trees[1]
	if not tree then
		return
	end
	local objects = {}
	collect_objects(tree:root(), category, objects)
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row, col = cursor[1] - 1, cursor[2]
	local selected
	for _, node in ipairs(objects) do
		local sr, sc, er, ec = node:range()
		local target_row, target_col = boundary == "end" and er or sr, boundary == "end" and ec or sc
		local after = position_before(row, col, target_row, target_col)
		local before = position_before(target_row, target_col, row, col)
		if (direction > 0 and after) or (direction < 0 and before) then
			if not selected then
				selected = { node = node, row = target_row, col = target_col }
			else
				local better = direction > 0 and position_before(target_row, target_col, selected.row, selected.col)
					or direction < 0 and position_before(selected.row, selected.col, target_row, target_col)
				if better then
					selected = { node = node, row = target_row, col = target_col }
				end
			end
		end
	end
	if selected then
		vim.cmd("normal! m'")
		vim.api.nvim_win_set_cursor(0, { selected.row + 1, selected.col })
	end
end

local function node_text(buf, node)
	local sr, sc, er, ec = node:range()
	return vim.api.nvim_buf_get_text(buf, sr, sc, er, ec, {})
end

local function swap_parameter(direction)
	local buf = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local row, col = cursor[1] - 1, cursor[2]
	local container = parameter_container(current_path(buf))
	if not container then
		return
	end
	local current, params = parameter_child(container, row, col)
	if not current then
		return
	end
	local current_index
	for index, node in ipairs(params) do
		if node:id() == current:id() then
			current_index = index
			break
		end
	end
	local neighbor = params[current_index and current_index + direction]
	if not neighbor or not current_index then
		return
	end
	local first, second = direction > 0 and current or neighbor, direction > 0 and neighbor or current
	local first_range, second_range = range(first), range(second)
	local first_text, second_text = node_text(buf, first), node_text(buf, second)
	vim.api.nvim_buf_set_text(
		buf,
		second_range.start[1],
		second_range.start[2],
		second_range.finish[1],
		second_range.finish[2],
		first_text
	)
	vim.api.nvim_buf_set_text(
		buf,
		first_range.start[1],
		first_range.start[2],
		first_range.finish[1],
		first_range.finish[2],
		second_text
	)
end

---Swap the current argument or parameter with its next sibling.
function M.swap_next()
	swap_parameter(1)
end

---Swap the current argument or parameter with its previous sibling.
function M.swap_previous()
	swap_parameter(-1)
end

---Register syntax-based textobject selection, movement, and argument swapping.
function M.setup()
	local groups = {
		{ "af", "function_", false, "Outer function" },
		{ "if", "function_", true, "Inner function body" },
		{ "ac", "class", false, "Outer class" },
		{ "ic", "class", true, "Inner class body" },
		{ "ai", "conditional", false, "Outer conditional" },
		{ "ii", "conditional", true, "Inner conditional body" },
		{ "al", "loop", false, "Outer loop" },
		{ "il", "loop", true, "Inner loop body" },
		{ "aa", "parameter", false, "Outer argument" },
		{ "ia", "parameter", true, "Inner argument" },
		{ "ab", "block", false, "Outer block" },
		{ "ib", "block", true, "Inner block" },
	}
	for _, mapping in ipairs(groups) do
		local key, category, inner, desc = unpack(mapping)
		vim.keymap.set({ "o", "x" }, key, function()
			M.select(category, inner)
		end, { desc = desc })
	end
	local motions = {
		{ "]f", "function_", 1, "start", "Next function start" },
		{ "[f", "function_", -1, "start", "Previous function start" },
		{ "]F", "function_", 1, "end", "Next function end" },
		{ "[F", "function_", -1, "end", "Previous function end" },
		{ "]c", "class", 1, "start", "Next class start" },
		{ "[c", "class", -1, "start", "Previous class start" },
		{ "]C", "class", 1, "end", "Next class end" },
		{ "[C", "class", -1, "end", "Previous class end" },
		{ "]a", "parameter", 1, "start", "Next argument" },
		{ "[a", "parameter", -1, "start", "Previous argument" },
	}
	for _, mapping in ipairs(motions) do
		local key, category, direction, boundary, desc = unpack(mapping)
		vim.keymap.set("n", key, function()
			M.move(category, direction, boundary)
		end, { desc = desc })
	end
	vim.keymap.set("n", "<leader>sn", M.swap_next, { desc = "Swap next argument" })
	vim.keymap.set("n", "<leader>sp", M.swap_previous, { desc = "Swap previous argument" })
end

return M
