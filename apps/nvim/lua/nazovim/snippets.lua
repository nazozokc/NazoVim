local M = {}

local namespace = vim.api.nvim_create_namespace("NazoSnippets")
local catalog = {}
local active = {}
local cmp_registered = false

local function snippet_dir()
	return vim.fn.expand(vim.g.nazovim_snippet_dir or (vim.fn.stdpath("config") .. "/snippets"))
end

local function add_definition(filetype, definition, origin)
	if type(definition) ~= "table" or type(definition.body) ~= "table" and type(definition.body) ~= "string" then
		return
	end
	local prefixes = type(definition.prefix) == "table" and definition.prefix or { definition.prefix }
	local body = type(definition.body) == "table" and table.concat(definition.body, "\n") or definition.body
	if type(body) ~= "string" then
		return
	end
	local scope = definition.scope or filetype
	local filetypes = type(scope) == "string" and vim.split(scope, ",", { trimempty = true }) or { filetype }
	for _, target in ipairs(filetypes) do
		local normalized = vim.trim(target)
		catalog[normalized] = catalog[normalized] or {}
		for _, prefix in ipairs(prefixes) do
			if type(prefix) == "string" and prefix ~= "" then
				catalog[normalized][#catalog[normalized] + 1] = {
					prefix = prefix,
					body = body,
					description = definition.description or definition.name or prefix,
					origin = origin,
				}
			end
		end
	end
end

local function load_catalog()
	catalog = {}
	local directory = snippet_dir()
	if vim.fn.isdirectory(directory) == 0 then
		return
	end
	for _, path in ipairs(vim.fn.globpath(directory, "**/*.json", false, true)) do
		local filetype = vim.fn.fnamemodify(path, ":t:r")
		local ok, decoded = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), "\n"))
		if ok and type(decoded) == "table" then
			for name, definition in pairs(decoded) do
				if type(definition) == "table" then
					definition.name = definition.name or name
					add_definition(filetype, definition, path)
				end
			end
		else
			vim.notify("Could not load snippet file " .. path .. ": " .. tostring(decoded), vim.log.levels.WARN, {
				title = "NazoVim Snippets",
			})
		end
	end
end

local function variable_value(name)
	local path = vim.api.nvim_buf_get_name(0)
	local base = vim.fn.fnamemodify(path, ":t:r")
	local values = {
		TM_FILENAME = vim.fn.fnamemodify(path, ":t"),
		TM_FILENAME_BASE = base,
		TM_DIRECTORY = vim.fn.fnamemodify(path, ":h"),
		CURRENT_YEAR = os.date("%Y"),
		CURRENT_MONTH = os.date("%m"),
		CURRENT_DATE = os.date("%d"),
		CURRENT_HOUR = os.date("%H"),
		CURRENT_MINUTE = os.date("%M"),
	}
	return values[name] or ""
end

local function parse(body)
	local chunks, placeholders, values = {}, {}, {}
	local offset, final_offset, index = 0, nil, 1
	local function append(text)
		chunks[#chunks + 1] = text
		offset = offset + #text
	end
	local function placeholder(number, fallback)
		local value = values[number]
		if value == nil then
			value = fallback or ""
			values[number] = value
		end
		local start_offset = offset
		append(value)
		if number == 0 then
			final_offset = start_offset
		else
			placeholders[number] = placeholders[number] or {}
			placeholders[number][#placeholders[number] + 1] = { start_offset, offset }
		end
	end

	while index <= #body do
		local character = body:sub(index, index)
		if character == "\\" and index < #body and body:sub(index + 1, index + 1):match("[$}\\]") then
			append(body:sub(index + 1, index + 1))
			index = index + 2
		elseif character == "$" then
			local digits = body:match("^(%d+)", index + 1)
			if digits then
				placeholder(tonumber(digits), "")
				index = index + #digits + 1
			elseif body:sub(index + 1, index + 1) == "{" then
				local close = body:find("}", index + 2, true)
				local token = close and body:sub(index + 2, close - 1)
				local number, fallback, choice_number, choices
				if token then
					number, fallback = token:match("^(%d+):(.*)$")
					choice_number, choices = token:match("^(%d+)|(.+)|$")
				end
				local simple_number = token and token:match("^(%d+)$")
				if number then
					placeholder(tonumber(number), fallback)
					index = close + 1
				elseif choice_number then
					placeholder(tonumber(choice_number), choices:match("^([^,]*)") or "")
					index = close + 1
				elseif simple_number then
					placeholder(tonumber(simple_number), "")
					index = close + 1
				elseif token and token:match("^[%a_][%w_]*$") then
					append(variable_value(token))
					index = close + 1
				else
					append(character)
					index = index + 1
				end
			else
				local variable = body:match("^([%a_][%w_]*)", index + 1)
				if variable then
					append(variable_value(variable))
					index = index + #variable + 1
				else
					append(character)
					index = index + 1
				end
			end
		else
			append(character)
			index = index + 1
		end
	end

	local text = table.concat(chunks)
	local numbers = vim.tbl_keys(placeholders)
	table.sort(numbers)
	local stops = {}
	local function position(byte_offset)
		local prefix = text:sub(1, byte_offset)
		local _, row = prefix:gsub("\n", "")
		local last_newline = prefix:match(".*()\n") or 0
		return row, #prefix - last_newline
	end
	for _, number in ipairs(numbers) do
		local stop = { number = number, ranges = {} }
		for _, range in ipairs(placeholders[number]) do
			local start_row, start_col = position(range[1])
			local end_row, end_col = position(range[2])
			stop.ranges[#stop.ranges + 1] = { start = { start_row, start_col }, finish = { end_row, end_col } }
		end
		stops[#stops + 1] = stop
	end
	local cursor_row, cursor_col = position(final_offset or #text)
	stops[#stops + 1] = { number = 0, ranges = {}, cursor = { cursor_row, cursor_col } }
	return text, stops
end

local function mark_stops(buf, stops, origin_row, origin_col)
	local function absolute(position)
		if position[1] == 0 then
			return origin_row, origin_col + position[2]
		end
		return origin_row + position[1], position[2]
	end
	for _, stop in ipairs(stops) do
		for _, range in ipairs(stop.ranges) do
			local start_row, start_col = absolute(range.start)
			local end_row, end_col = absolute(range.finish)
			range.start_id = vim.api.nvim_buf_set_extmark(buf, namespace, start_row, start_col, {
				right_gravity = false,
			})
			range.end_id = vim.api.nvim_buf_set_extmark(buf, namespace, end_row, end_col, {
				right_gravity = true,
			})
		end
		if stop.number == 0 then
			local cursor_row, cursor_col = absolute(stop.cursor)
			stop.cursor_id = vim.api.nvim_buf_set_extmark(buf, namespace, cursor_row, cursor_col, {
				right_gravity = false,
			})
		end
	end
end

local function get_mark(buf, id)
	local position, details = vim.api.nvim_buf_get_extmark_by_id(buf, namespace, id, { details = true })
	if #position == 0 then
		return nil
	end
	return { position[1], position[2], details }
end

local function sync_stop(state, stop)
	if not stop or #stop.ranges < 2 then
		return
	end
	local current = stop.ranges[1]
	local start = get_mark(state.buf, current.start_id)
	local finish = get_mark(state.buf, current.end_id)
	if not start or not finish then
		return
	end
	local replacement = vim.api.nvim_buf_get_text(state.buf, start[1], start[2], finish[1], finish[2], {})
	local targets = {}
	for index = 2, #stop.ranges do
		local range = stop.ranges[index]
		local target_start = get_mark(state.buf, range.start_id)
		local target_end = get_mark(state.buf, range.end_id)
		if target_start and target_end then
			targets[#targets + 1] = { start = target_start, finish = target_end }
		end
	end
	table.sort(targets, function(left, right)
		if left.start[1] == right.start[1] then
			return left.start[2] > right.start[2]
		end
		return left.start[1] > right.start[1]
	end)
	for _, target in ipairs(targets) do
		vim.api.nvim_buf_set_text(
			state.buf,
			target.start[1],
			target.start[2],
			target.finish[1],
			target.finish[2],
			replacement
		)
	end
end

local function clear_state(buf)
	local state = active[buf]
	if state then
		vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
		active[buf] = nil
	end
end

function M.jumpable(direction)
	local state = active[vim.api.nvim_get_current_buf()]
	return state ~= nil and state.index + direction >= 1 and state.index + direction <= #state.stops
end

function M.jump(direction)
	local buf = vim.api.nvim_get_current_buf()
	local state = active[buf]
	if not state or not M.jumpable(direction) then
		return false
	end
	sync_stop(state, state.stops[state.index])
	state.index = state.index + direction
	local stop = state.stops[state.index]
	if stop.number == 0 then
		local cursor = get_mark(buf, stop.cursor_id)
		if cursor then
			vim.api.nvim_win_set_cursor(0, { cursor[1] + 1, cursor[2] })
		end
	elseif stop.ranges[1] then
		local start = get_mark(buf, stop.ranges[1].start_id)
		if start then
			vim.api.nvim_win_set_cursor(0, { start[1] + 1, start[2] })
		end
	end
	return true
end

function M.expand(body)
	local buf = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local start_row, start_col = cursor[1] - 1, cursor[2]
	local text, stops = parse(body)
	vim.api.nvim_buf_set_text(buf, start_row, start_col, start_row, start_col, vim.split(text, "\n", { plain = true }))
	vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
	mark_stops(buf, stops, start_row, start_col)
	active[buf] = { buf = buf, stops = stops, index = 0 }
	if stops[1] and stops[1].number ~= 0 then
		return M.jump(1)
	end
	local final = get_mark(buf, stops[#stops].cursor_id)
	vim.api.nvim_win_set_cursor(0, { final[1] + 1, final[2] })
	return true
end

local function entries_for(filetype)
	local result = {}
	for _, scope in ipairs({ "all", filetype }) do
		for _, definition in ipairs(catalog[scope] or {}) do
			result[#result + 1] = definition
		end
	end
	return result
end

---Return snippet definitions for the current buffer whose prefix matches.
---@param prefix? string
---@return table[]
function M.candidates(prefix)
	local result = {}
	prefix = prefix or ""
	for _, definition in ipairs(entries_for(vim.bo.filetype)) do
		if prefix == "" or definition.prefix:sub(1, #prefix) == prefix then
			result[#result + 1] = definition
		end
	end
	return result
end

local function expand_definition(definition, trigger)
	local buf = vim.api.nvim_get_current_buf()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local start_col = cursor[2] - #trigger
	vim.api.nvim_buf_set_text(buf, cursor[1] - 1, start_col, cursor[1] - 1, cursor[2], {})
	vim.api.nvim_win_set_cursor(0, { cursor[1], start_col })
	M.expand(definition.body)
end

function M.expand_trigger(trigger)
	local buf = vim.api.nvim_get_current_buf()
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
	local typed = line:sub(1, col):match("([%w_%-]+)$")
	trigger = trigger or typed
	if not trigger or trigger == "" or typed ~= trigger then
		return false
	end
	local matches = {}
	for _, definition in ipairs(entries_for(vim.bo[buf].filetype)) do
		if definition.prefix == trigger then
			matches[#matches + 1] = definition
		end
	end
	if #matches == 0 then
		return false
	end
	local function expand(definition)
		if not definition then
			return
		end
		if not vim.api.nvim_buf_is_valid(buf) then
			return
		end
		vim.api.nvim_set_current_buf(buf)
		expand_definition(definition, trigger)
	end
	if #matches == 1 then
		expand(matches[1])
	else
		vim.ui.select(matches, {
			prompt = "Choose snippet",
			format_item = function(item)
				return item.description
			end,
		}, expand)
	end
	return true
end

function M.complete(params, callback)
	local context = params.context
	local before = context and context.cursor_before_line or ""
	local prefix = before:match("([%w_%-]+)$") or ""
	if prefix == "" then
		callback({ items = {}, isIncomplete = false })
		return
	end
	local items = {}
	for _, definition in ipairs(entries_for(vim.bo[context.bufnr].filetype)) do
		if definition.prefix:sub(1, #prefix) == prefix then
			items[#items + 1] = {
				label = definition.prefix,
				filterText = definition.prefix,
				detail = definition.description,
				documentation = { kind = "plaintext", value = definition.description },
				kind = 15,
				insertText = definition.body,
				insertTextFormat = 2,
			}
		end
	end
	callback({ items = items, isIncomplete = false })
end

function M.register(cmp)
	if cmp_registered then
		return
	end
	cmp.register_source("nazovim_snippets", {
		complete = function(params, callback)
			M.complete(params, callback)
		end,
	})
	cmp_registered = true
end

function M.reload()
	load_catalog()
	vim.notify("Loaded user snippets from " .. snippet_dir(), vim.log.levels.INFO, { title = "NazoVim Snippets" })
end

function M.setup()
	load_catalog()
	vim.api.nvim_create_user_command("NazoSnippetExpand", function(command)
		if not M.expand_trigger(command.args ~= "" and command.args or nil) then
			vim.notify("No matching snippet at the cursor", vim.log.levels.INFO, { title = "NazoVim Snippets" })
		end
	end, { nargs = "?", desc = "Expand a snippet at the cursor" })
	vim.api.nvim_create_user_command("NazoSnippetReload", M.reload, { desc = "Reload user snippet JSON files" })
	vim.api.nvim_create_autocmd("BufWipeout", {
		group = vim.api.nvim_create_augroup("NazoSnippets", { clear = true }),
		callback = function(args)
			clear_state(args.buf)
		end,
	})
end

return M
