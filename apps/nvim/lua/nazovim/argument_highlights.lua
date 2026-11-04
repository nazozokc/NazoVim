local M = {}

local namespace = vim.api.nvim_create_namespace("NazoArgumentHighlights")
local previous_buffer
local enabled = true
local function_types = {
	arrow_function = true,
	closure_expression = true,
	function_declaration = true,
	function_definition = true,
	function_expression = true,
	function_item = true,
	function_literal = true,
	func_literal = true,
	lambda = true,
	lambda_expression = true,
	method = true,
	method_declaration = true,
	method_definition = true,
}

local function clear(buf)
	if buf and vim.api.nvim_buf_is_valid(buf) then
		vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
	end
end

local function function_node(node)
	while node do
		local kind = node:type()
		if function_types[kind] then
			return node
		end
		node = node:parent()
	end
end

local function mark(buf, node)
	local start_row, start_col, end_row, end_col = node:range()
	if start_row < 0 or end_row >= vim.api.nvim_buf_line_count(buf) then
		return
	end
	vim.api.nvim_buf_set_extmark(buf, namespace, start_row, start_col, {
		end_row = end_row,
		end_col = end_col,
		hl_group = "NazoArgument",
		priority = 150,
		strict = false,
	})
end

local function update()
	if previous_buffer then
		clear(previous_buffer)
	end
	local buf = vim.api.nvim_get_current_buf()
	previous_buffer = buf
	if not enabled or vim.bo[buf].buftype ~= "" or vim.api.nvim_buf_line_count(buf) > 5000 then
		return
	end
	local ok, current = pcall(vim.treesitter.get_node, { bufnr = buf })
	if not ok or not current then
		return
	end
	local root = function_node(current)
	if not root then
		return
	end

	local parser_ok, parser = pcall(vim.treesitter.get_parser, buf)
	if not parser_ok or not parser then
		return
	end
	local language = parser:lang()
	local query = vim.treesitter.query.get(language, "highlights")
	if not query then
		return
	end

	local start_row, _, end_row = root:range()
	local seen = {}
	local locals_ok, locals = pcall(require, "nazovim.locals")
	-- A language query can contain parser-specific captures; skip unsupported trees safely.
	pcall(function()
		for capture, node in query:iter_captures(root, buf, start_row, end_row + 1) do
			if query.captures[capture]:find("parameter", 1, true) and not seen[node:id()] then
				seen[node:id()] = true
				mark(buf, node)
				if locals_ok then
					local resolved, usages = pcall(function()
						local definition, scope = locals.find_definition(node, buf)
						return locals.find_usages(definition, scope, buf)
					end)
					if resolved then
						for _, usage in ipairs(usages or {}) do
							if not seen[usage:id()] then
								seen[usage:id()] = true
								mark(buf, usage)
							end
						end
					end
				end
			end
		end
	end)
end

---Toggle highlighting of arguments in the function under the cursor.
function M.toggle()
	enabled = not enabled
	if not enabled then
		clear(previous_buffer)
	else
		update()
	end
	vim.notify("Argument highlights " .. (enabled and "enabled" or "disabled"), vim.log.levels.INFO, {
		title = "NazoVim",
	})
end

---Highlight current-function arguments using Treesitter captures and local resolution.
function M.setup()
	enabled = vim.g.nazovim_argument_highlights ~= false
	vim.api.nvim_set_hl(0, "NazoArgument", { link = "@variable.parameter", default = true })
	local group = vim.api.nvim_create_augroup("NazoArgumentHighlights", { clear = true })
	local update_debounced = require("nazovim.ui").throttle(90, update)
	vim.api.nvim_create_autocmd({ "CursorMoved", "BufEnter", "TextChanged", "LspAttach" }, {
		group = group,
		callback = update_debounced,
	})
	vim.api.nvim_create_autocmd({ "BufLeave", "InsertEnter" }, {
		group = group,
		callback = function(event)
			clear(event.buf)
		end,
	})
	vim.api.nvim_create_autocmd("InsertLeave", {
		group = group,
		callback = update_debounced,
	})
	vim.api.nvim_create_user_command("NazoArgumentHighlightsToggle", M.toggle, {
		desc = "Toggle argument highlights",
	})
end

return M
