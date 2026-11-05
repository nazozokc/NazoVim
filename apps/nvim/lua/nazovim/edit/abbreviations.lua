local M = {}

local void_tags = {
	area = true,
	base = true,
	br = true,
	col = true,
	embed = true,
	hr = true,
	img = true,
	input = true,
	link = true,
	meta = true,
	param = true,
	source = true,
	track = true,
	wbr = true,
}

local css_properties = {
	bgc = "background-color",
	bgi = "background-image",
	bgr = "background-repeat",
	bgs = "background-size",
	bgp = "background-position",
	bd = "border",
	bdc = "border-color",
	bdr = "border-radius",
	bdw = "border-width",
	bt = "border-top",
	br = "border-right",
	bb = "border-bottom",
	bl = "border-left",
	c = "color",
	d = "display",
	f = "font",
	ff = "font-family",
	fw = "font-weight",
	fz = "font-size",
	lh = "line-height",
	m = "margin",
	mb = "margin-bottom",
	ml = "margin-left",
	mm = "margin",
	mt = "margin-top",
	mr = "margin-right",
	p = "padding",
	pr = "padding-right",
	pl = "padding-left",
	pt = "padding-top",
	pb = "padding-bottom",
	h = "height",
	w = "width",
	maw = "max-width",
	mah = "max-height",
	miw = "min-width",
	mih = "min-height",
	op = "opacity",
	pos = "position",
	t = "top",
	r = "right",
	b = "bottom",
	l = "left",
	z = "z-index",
}
local css_abbreviations = vim.tbl_keys(css_properties)
table.sort(css_abbreviations, function(left, right)
	return #left > #right
end)

local function is_delimiter(character)
	return character == ""
		or character == "."
		or character == "#"
		or character == "["
		or character == "]"
		or character == "{"
		or character == "}"
		or character == ">"
		or character == "+"
		or character == "*"
		or character == "("
		or character == ")"
end

local function parse_attributes(value)
	local attributes, index = {}, 1
	while index <= #value do
		while value:sub(index, index):match("%s") do
			index = index + 1
		end
		if index > #value then
			break
		end
		local start = index
		while index <= #value and not value:sub(index, index):match("[%s=]") do
			index = index + 1
		end
		local name = value:sub(start, index - 1)
		if name == "" then
			return nil
		end
		while value:sub(index, index):match("%s") do
			index = index + 1
		end
		local attribute = { name = name }
		if value:sub(index, index) == "=" then
			index = index + 1
			while value:sub(index, index):match("%s") do
				index = index + 1
			end
			local quote = value:sub(index, index)
			if quote == "'" or quote == '"' then
				index = index + 1
				local finish = value:find(quote, index, true)
				if not finish then
					return nil
				end
				attribute.value = value:sub(index, finish - 1)
				index = finish + 1
			else
				local value_start = index
				while index <= #value and not value:sub(index, index):match("%s") do
					index = index + 1
				end
				attribute.value = value:sub(value_start, index - 1)
			end
		end
		attributes[#attributes + 1] = attribute
	end
	return attributes
end

local function parse_term(source, cursor)
	local start = cursor
	while cursor <= #source and not is_delimiter(source:sub(cursor, cursor)) do
		cursor = cursor + 1
	end
	local tag = source:sub(start, cursor - 1)
	local node = { tag = tag ~= "" and tag or "div", classes = {}, attributes = {}, children = {} }
	while cursor <= #source do
		local marker = source:sub(cursor, cursor)
		if marker == "#" or marker == "." then
			cursor = cursor + 1
			local name_start = cursor
			while cursor <= #source and not is_delimiter(source:sub(cursor, cursor)) do
				cursor = cursor + 1
			end
			local name = source:sub(name_start, cursor - 1)
			if name == "" then
				return nil, cursor
			end
			if marker == "#" then
				if node.id then
					return nil, cursor
				end
				node.id = name
			else
				node.classes[#node.classes + 1] = name
			end
		elseif marker == "[" then
			local finish = source:find("]", cursor + 1, true)
			if not finish then
				return nil, cursor
			end
			local attributes = parse_attributes(source:sub(cursor + 1, finish - 1))
			if not attributes then
				return nil, cursor
			end
			vim.list_extend(node.attributes, attributes)
			cursor = finish + 1
		elseif marker == "{" then
			local finish = source:find("}", cursor + 1, true)
			if not finish then
				return nil, cursor
			end
			node.text = source:sub(cursor + 1, finish - 1)
			cursor = finish + 1
		elseif marker == "*" then
			cursor = cursor + 1
			local count = source:match("^(%d+)", cursor)
			if not count then
				return nil, cursor
			end
			node.repeat_count = math.min(tonumber(count), 100)
			cursor = cursor + #count
		else
			break
		end
	end
	return node, cursor
end

local function parse_expression(source, cursor, stop_at_group)
	local nodes = {}
	while cursor <= #source do
		local node
		if source:sub(cursor, cursor) == "(" then
			local group
			group, cursor = parse_expression(source, cursor + 1, true)
			if not group or #group == 0 then
				return nil, cursor
			end
			local count = source:match("^(%d+)", cursor)
			if source:sub(cursor, cursor) == "*" then
				if not count then
					return nil, cursor
				end
				local repetitions = math.min(tonumber(count), 100)
				for _, grouped_node in ipairs(group) do
					grouped_node.repeat_count = (grouped_node.repeat_count or 1) * repetitions
				end
				cursor = cursor + #count
			end
			vim.list_extend(nodes, group)
		else
			node, cursor = parse_term(source, cursor)
			if not node then
				return nil, cursor
			end
			nodes[#nodes + 1] = node
		end
		local last_node = nodes[#nodes]
		if source:sub(cursor, cursor) == ">" then
			local children
			children, cursor = parse_expression(source, cursor + 1, true)
			if not children or #children == 0 then
				return nil, cursor
			end
			last_node.children = children
		end
		if source:sub(cursor, cursor) == "+" then
			cursor = cursor + 1
		elseif stop_at_group and source:sub(cursor, cursor) == ")" then
			return nodes, cursor + 1
		else
			break
		end
	end
	return nodes, cursor
end

local function replace_number(value, number)
	return (value or ""):gsub("%$", tostring(number or 1))
end

local function render_node(node, depth, number, lines, indent_unit)
	local indent = string.rep(indent_unit, depth)
	local tag = replace_number(node.tag, number)
	local attributes = {}
	if node.id then
		attributes[#attributes + 1] = 'id="' .. replace_number(node.id, number) .. '"'
	end
	if #node.classes > 0 then
		attributes[#attributes + 1] = 'class="'
			.. table.concat(
				vim.tbl_map(function(class)
					return replace_number(class, number)
				end, node.classes),
				" "
			)
			.. '"'
	end
	for _, attribute in ipairs(node.attributes) do
		attributes[#attributes + 1] = replace_number(attribute.name, number)
			.. (attribute.value and ('="' .. replace_number(attribute.value, number) .. '"') or "")
	end
	local opening = "<" .. tag .. (#attributes > 0 and (" " .. table.concat(attributes, " ")) or "")
	local count = node.repeat_count or 1
	for iteration = 1, count do
		local line = opening .. ">"
		local text = replace_number(node.text, iteration)
		if void_tags[tag:lower()] then
			lines[#lines + 1] = indent .. opening .. " />"
		elseif #node.children == 0 and text ~= "" then
			lines[#lines + 1] = indent .. line .. text .. "</" .. tag .. ">"
		else
			lines[#lines + 1] = indent .. line
			if text ~= "" then
				lines[#lines + 1] = string.rep(indent_unit, depth + 1) .. text
			end
			for _, child in ipairs(node.children) do
				render_node(child, depth + 1, iteration, lines, indent_unit)
			end
			lines[#lines + 1] = indent .. "</" .. tag .. ">"
		end
	end
end

---Expand a supported HTML abbreviation into indented markup lines.
function M.expand_html(source, base_indent, indent_unit)
	if source == "" then
		return nil
	end
	base_indent = base_indent or ""
	indent_unit = indent_unit or "\t"
	local nodes, cursor = parse_expression(source, 1, false)
	if not nodes or cursor <= #source then
		return nil
	end
	local lines = {}
	for _, node in ipairs(nodes) do
		local rendered = {}
		render_node(node, 0, nil, rendered, indent_unit)
		for _, line in ipairs(rendered) do
			lines[#lines + 1] = #lines == 0 and line or (base_indent .. line)
		end
	end
	return lines
end

local function expand_css(source)
	local name, separator, value = source:match("^([%a]+)([:#]?)([%w%.%%%-]*)$")
	if not name then
		return nil
	end
	local property
	local abbreviation_prefix
	for _, abbreviation in ipairs(css_abbreviations) do
		if name:sub(1, #abbreviation) == abbreviation then
			property = css_properties[abbreviation]
			abbreviation_prefix = abbreviation
			value = name:sub(#abbreviation + 1) .. separator .. value
			break
		end
	end
	if not property then
		return nil
	end
	local symbols = {
		["d:f"] = "flex",
		["d:g"] = "grid",
		["d:b"] = "block",
		["d:i"] = "inline",
		["d:ib"] = "inline-block",
		["pos:a"] = "absolute",
		["pos:r"] = "relative",
		["pos:f"] = "fixed",
		["pos:s"] = "sticky",
	}
	local shorthand = abbreviation_prefix .. value
	if symbols[shorthand] then
		value = symbols[shorthand]
	elseif value:sub(1, 1) == "#" then
		value = value
	elseif value == "" then
		return nil
	elseif value:match("^%-?%d+%.?%d*$") and value ~= "0" and property ~= "opacity" and property ~= "z-index" then
		value = value .. "px"
	elseif value:match("^%-?%d+%.?%d*p$") then
		value = value:sub(1, -2) .. "%"
	elseif value:match("^%-?%d+%.?%d*$") and property == "opacity" and tonumber(value) > 1 then
		value = tostring(tonumber(value) / 100)
	end
	return property .. ": " .. value .. ";"
end

local function expand()
	local buf = vim.api.nvim_get_current_buf()
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
	local prefix = line:sub(1, col)
	local abbreviation = prefix:match("([%w_#%.%-%$%[%]=/'\"{}+>*()]+)$")
	if not abbreviation then
		return
	end
	local filetype = vim.bo[buf].filetype
	local replacement
	if filetype == "css" or filetype == "scss" or filetype == "less" then
		local declaration = expand_css(abbreviation)
		replacement = declaration and { declaration } or nil
	elseif
		vim.tbl_contains({
			"html",
			"xhtml",
			"xml",
			"vue",
			"svelte",
			"javascript",
			"javascriptreact",
			"typescript",
			"typescriptreact",
			"astro",
		}, filetype)
	then
		local indent = line:match("^%s*") or ""
		local indent_unit = vim.bo[buf].expandtab and string.rep(" ", math.max(vim.bo[buf].shiftwidth, 1)) or "\t"
		replacement = M.expand_html(abbreviation, indent, indent_unit)
	else
		return
	end
	if not replacement then
		return
	end
	local start_col = col - #abbreviation
	vim.api.nvim_buf_set_text(buf, row - 1, start_col, row - 1, col, replacement)
	local last_line = replacement[#replacement] or ""
	vim.api.nvim_win_set_cursor(0, { row - 1 + #replacement, start_col + #last_line })
end

---Install the original abbreviation expander on the configured trigger.
function M.setup()
	vim.keymap.set("i", "<C-e>,", expand, { desc = "Expand HTML/CSS abbreviation" })
end

return M
