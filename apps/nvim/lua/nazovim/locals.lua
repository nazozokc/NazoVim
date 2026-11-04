local M = {}

local ts = vim.treesitter

local kinds = { definition = true, reference = true, scope = true }

---Split a capture name into its kind and suffix.
---Both `definition.var` and the grouped `local.definition.var` are accepted.
---@param capture string
---@return string? kind
---@return string? suffix
local function classify(capture)
	local kind, suffix
	for segment in capture:gmatch("[^%.]+") do
		if kind then
			suffix = suffix and (suffix .. "." .. segment) or segment
		elseif kinds[segment] then
			kind = segment
		end
	end
	return kind, suffix
end

---Collect the `locals` query matches for a buffer.
---Each entry is `{ definition?, scope?, reference? }` where every value holds
---the node and the capture suffix (`definition.var` -> `var`).
---@param bufnr integer
---@param root? TSNode
---@return { definition?: table, scope?: table, reference?: table }[]
local function collect(bufnr, root)
	local ok, parser = pcall(ts.get_parser, bufnr)
	if not ok or not parser then
		return {}
	end
	local language = parser:lang()
	local query = ts.query.get(language, "locals")
	if not query then
		return {}
	end
	root = root or parser:parse()[1]:root()

	local entries = {}
	pcall(function()
		for _, match in query:iter_matches(root, bufnr) do
			local entry = {}
			for id, node in pairs(match) do
				local kind, suffix = classify(query.captures[id] or "")
				if kind then
					local nodes = type(node) == "table" and node or { node }
					for _, item in ipairs(nodes) do
						if item then
							entry[kind] = { node = item, kind = suffix or kind }
						end
					end
				end
			end
			if next(entry) then
				entries[#entries + 1] = entry
			end
		end
	end)
	return entries
end

---Cache the parsed locals per buffer, keyed by `changedtick`.
local cache = {}

---@param bufnr integer
---@return { definitions: table[], scopes: table, references: table[] }
local function buffer_locals(bufnr)
	local tick = vim.api.nvim_buf_get_changedtick(bufnr)
	local cached = cache[bufnr]
	if cached and cached.tick == tick then
		return cached
	end
	local entries = collect(bufnr)
	local scopes = {}
	local definitions = {}
	local references = {}
	for _, entry in ipairs(entries) do
		if entry.scope then
			scopes[entry.scope.node:id()] = entry.scope.node
		end
		if entry.definition then
			definitions[#definitions + 1] = entry.definition
		end
		if entry.reference then
			references[#references + 1] = entry.reference
		end
	end
	cached = { tick = tick, entries = entries, scopes = scopes, definitions = definitions, references = references }
	cache[bufnr] = cached
	return cached
end

---Return the nearest enclosing scope node, falling back to the buffer root.
---@param node TSNode
---@param bufnr integer
---@return TSNode
function M.containing_scope(node, bufnr)
	local scopes = buffer_locals(bufnr).scopes
	local current = node
	while current do
		if scopes[current:id()] then
			return current
		end
		current = current:parent()
	end
	return node:tree():root()
end

---Return the scope chain of a node from the nearest scope up to the root.
---@param node TSNode
---@param bufnr integer
---@return TSNode[]
function M.scope_chain(node, bufnr)
	local result = {}
	local current = M.containing_scope(node, bufnr)
	while current do
		result[#result + 1] = current
		local parent = current:parent()
		current = parent and M.containing_scope(parent, bufnr) or nil
		if current and current:id() == result[#result]:id() then
			current = nil
		end
	end
	return result
end

local function definition_id(scope, text)
	return table.concat({ "k", text or "", scope:range() }, "_")
end

---Build the lookup table of definitions, keyed by scope range and text.
---@param bufnr integer
---@return table<string, table>
local function definitions_lookup(bufnr)
	local state = buffer_locals(bufnr)
	local result = {}
	for _, definition in ipairs(state.definitions) do
		local scope_type = definition.kind or "local"
		local chain = M.scope_chain(definition.node, bufnr)
		local scope = chain[#chain] or definition.node:tree():root()
		if scope_type == "parent" then
			scope = chain[2] or chain[1] or scope
		elseif scope_type ~= "global" then
			scope = chain[1] or scope
		end
		local text = ts.get_node_text(definition.node, bufnr)
		result[definition_id(scope, text)] = definition
	end
	return result
end

---Find the definition node of a node.
---@param node TSNode
---@param bufnr integer
---@return TSNode definition
---@return TSNode scope
---@return string? kind
function M.find_definition(node, bufnr)
	local lookup = definitions_lookup(bufnr)
	local text = ts.get_node_text(node, bufnr)
	for _, scope in ipairs(M.scope_chain(node, bufnr)) do
		local entry = lookup[definition_id(scope, text)]
		if entry then
			return entry.node, scope, entry.kind
		end
	end
	return node, node:tree():root(), nil
end

---Find the usages of a node within a scope.
---@param node TSNode
---@param scope_node? TSNode
---@param bufnr integer
---@return TSNode[]
function M.find_usages(node, scope_node, bufnr)
	local text = ts.get_node_text(node, bufnr)
	if not text or text == "" then
		return {}
	end
	local state = buffer_locals(bufnr)
	local scope = scope_node or node:tree():root()
	local start_row, _, end_row = scope:range()
	local usages = {}
	for _, reference in ipairs(state.references) do
		local ref_node = reference.node
		local row = ref_node:range()
		if row >= start_row and row <= end_row and ts.get_node_text(ref_node, bufnr) == text then
			local definition, _, kind = M.find_definition(ref_node, bufnr)
			if kind == nil or definition == node then
				usages[#usages + 1] = ref_node
			end
		end
	end
	return usages
end

return M
