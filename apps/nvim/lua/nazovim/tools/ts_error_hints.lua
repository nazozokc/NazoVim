local M = {}

local namespace = vim.api.nvim_create_namespace("NazoVimTypeScriptHints")
local enabled = true
local pending = {}

local explanations = {
	[2322] = "This value does not match the type required here.",
	[2345] = "The supplied argument does not match the parameter type.",
	[2339] = "This property is not declared on the current type.",
	[2304] = "This name is not defined in the current scope.",
	[2307] = "This module could not be resolved; check its path and installed types.",
	[7006] = "This parameter has no inferred type; add an explicit annotation.",
	[2531] = "This value may be null; check it before using it.",
	[2532] = "This value may be undefined; check it before using it.",
	[2551] = "This property is missing; check whether a similarly named property was intended.",
	[2554] = "The number of supplied arguments does not match the function signature.",
	[2349] = "This expression is not callable; its type has no call signature.",
	[2367] = "These values do not appear to overlap, so this comparison may always be false.",
	[2454] = "This variable may be read before it receives a value.",
	[2589] = "Type evaluation became too complex; simplify the related type expression.",
	[2677] = "The type predicate does not narrow to a compatible type.",
	[2741] = "A required property is missing from this object.",
	[2769] = "None of the available overloads accepts these arguments.",
	[18046] = "This value has type unknown; narrow or validate it before use.",
	[18048] = "This value may be undefined; check it before using it.",
}

local filetypes = {
	astro = true,
	javascript = true,
	javascriptreact = true,
	svelte = true,
	typescript = true,
	typescriptreact = true,
	vue = true,
}

local function error_code(diagnostic)
	local code = diagnostic.code
	if type(code) == "table" then
		code = code.value
	end
	local code_text = tostring(code or "")
	local number = tonumber(code_text:match("^TS(%d+)$") or code_text:match("^(%d+)$"))
	if number then
		return number
	end
	return tonumber((diagnostic.message or ""):match("TS(%d+)"))
end

local function collect(buf)
	local by_row = {}
	for _, diagnostic in ipairs(vim.diagnostic.get(buf)) do
		local code = error_code(diagnostic)
		local explanation = code and explanations[code]
		if explanation and diagnostic.lnum >= 0 and diagnostic.lnum < vim.api.nvim_buf_line_count(buf) then
			by_row[diagnostic.lnum] = by_row[diagnostic.lnum] or {}
			by_row[diagnostic.lnum][#by_row[diagnostic.lnum] + 1] = string.format("TS%d: %s", code, explanation)
		end
	end
	return by_row
end

local function render(buf)
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
	if not enabled or not filetypes[vim.bo[buf].filetype] then
		return
	end
	for row, messages in pairs(collect(buf)) do
		local text = table.concat(messages, "  ·  ")
		local maximum = math.max(40, math.min(240, tonumber(vim.g.nazovim_ts_error_hint_width) or 140))
		if vim.fn.strdisplaywidth(text) > maximum then
			text = vim.fn.strcharpart(text, 0, maximum - 1) .. "…"
		end
		vim.api.nvim_buf_set_extmark(buf, namespace, row, 0, {
			virt_text = { { "  ↳ ", "Comment" }, { text, "DiagnosticHint" } },
			virt_text_pos = "eol",
			priority = 90,
		})
	end
end

local function schedule(buf)
	if pending[buf] then
		return
	end
	pending[buf] = true
	vim.defer_fn(function()
		pending[buf] = nil
		if vim.api.nvim_buf_is_valid(buf) then
			render(buf)
		end
	end, 80)
end

---Enable TypeScript diagnostic explanations.
function M.enable()
	enabled = true
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) then
			schedule(buf)
		end
	end
end

---Disable TypeScript diagnostic explanations and clear their virtual text.
function M.disable()
	enabled = false
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
		end
	end
end

---Attach translated hints to diagnostics without replacing compiler messages.
function M.setup()
	enabled = vim.g.nazovim_ts_error_hints_enabled ~= false
	local group = vim.api.nvim_create_augroup("NazoVimTypeScriptHints", { clear = true })
	vim.api.nvim_create_autocmd({ "DiagnosticChanged", "BufEnter", "FileType" }, {
		group = group,
		callback = function(event)
			schedule(event.buf)
		end,
	})
	vim.api.nvim_create_user_command("NazoTypeHintsEnable", M.enable, { desc = "Enable TypeScript diagnostic hints" })
	vim.api.nvim_create_user_command(
		"NazoTypeHintsDisable",
		M.disable,
		{ desc = "Disable TypeScript diagnostic hints" }
	)
end

return M
