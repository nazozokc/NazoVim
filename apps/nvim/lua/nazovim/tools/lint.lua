local M = {}

local namespace = vim.api.nvim_create_namespace("NazoVimLint")
local requests = {}

local function buffer_path(buf)
	local path = vim.api.nvim_buf_get_name(buf)
	if path == "" then
		return nil
	end
	return vim.fn.fnamemodify(path, ":p")
end

local function message(text, line, column, severity, code, end_line, end_column)
	return {
		message = text,
		lnum = math.max((line or 1) - 1, 0),
		col = math.max((column or 1) - 1, 0),
		end_lnum = end_line and math.max(end_line - 1, 0) or nil,
		end_col = end_column and math.max(end_column - 1, 0) or nil,
		severity = severity,
		code = code,
	}
end

local function decode_json(output)
	local ok, value = pcall(vim.json.decode, output)
	if ok then
		return value
	end
	return nil
end

local function parse_eslint(output)
	local result = {}
	for _, file in ipairs(decode_json(output) or {}) do
		for _, item in ipairs(file.messages or {}) do
			result[#result + 1] = message(
				item.message or "ESLint diagnostic",
				item.line,
				item.column,
				item.severity == 2 and vim.diagnostic.severity.ERROR or vim.diagnostic.severity.WARN,
				item.ruleId
			)
		end
	end
	return result
end

local function parse_rubocop(output)
	local result = {}
	local data = decode_json(output)
	for _, file in ipairs(data and data.files or {}) do
		for _, offense in ipairs(file.offenses or {}) do
			local location = offense.location or {}
			local level = (offense.severity == "fatal" or offense.severity == "error") and vim.diagnostic.severity.ERROR
				or vim.diagnostic.severity.WARN
			result[#result + 1] = message(
				offense.message or "RuboCop offense",
				location.start_line,
				location.start_column,
				level,
				offense.cop_name,
				location.last_line,
				location.last_column
			)
		end
	end
	return result
end

local function parse_luacheck(output)
	local result = {}
	for line in output:gmatch("[^\r\n]+") do
		local row, column, code, detail = line:match("^.-:(%d+):(%d+): %((%u%d+)%) (.*)$")
		if row then
			local severity = code:sub(1, 1) == "E" and vim.diagnostic.severity.ERROR or vim.diagnostic.severity.WARN
			result[#result + 1] = message(detail, tonumber(row), tonumber(column), severity, code)
		end
	end
	return result
end

local function parse_markdownlint(output)
	local result = {}
	local data = decode_json(output) or {}
	for _, findings in pairs(data) do
		for _, item in ipairs(findings) do
			local rules = item.ruleNames or {}
			result[#result + 1] = message(
				item.ruleDescription and (item.ruleDescription .. ": " .. (item.errorDetail or item.errorContext or ""))
					or item.errorDetail
					or "Markdown lint issue",
				item.lineNumber,
				item.column,
				item.severity == "error" and vim.diagnostic.severity.ERROR or vim.diagnostic.severity.WARN,
				rules[1],
				item.lineNumber,
				item.range and item.range[2] and ((item.column or 1) + item.range[2] - 1) or nil
			)
		end
	end
	return result
end

local function parse_nix(output)
	local result = {}
	for line in output:gmatch("[^\r\n]+") do
		local row, column, detail = line:match(":(%d+):(%d+):%s*(.*)$")
		if row then
			result[#result + 1] =
				message(detail, tonumber(row), tonumber(column), vim.diagnostic.severity.ERROR, "nix-parse")
		end
	end
	return result
end

local linters = {
	javascript = {
		"eslint",
		parse_eslint,
		function(path)
			return { "eslint", "--format", "json", "--stdin", "--stdin-filename", path }, true
		end,
	},
	javascriptreact = {
		"eslint",
		parse_eslint,
		function(path)
			return { "eslint", "--format", "json", "--stdin", "--stdin-filename", path }, true
		end,
	},
	typescript = {
		"eslint",
		parse_eslint,
		function(path)
			return { "eslint", "--format", "json", "--stdin", "--stdin-filename", path }, true
		end,
	},
	typescriptreact = {
		"eslint",
		parse_eslint,
		function(path)
			return { "eslint", "--format", "json", "--stdin", "--stdin-filename", path }, true
		end,
	},
	ruby = {
		"rubocop",
		parse_rubocop,
		function(path)
			return { "rubocop", "--format", "json", "--stdin", path }, true
		end,
	},
	lua = {
		"luacheck",
		parse_luacheck,
		function(path)
			return { "luacheck", "--formatter", "plain", "--ranges", "--codes", "--filename", path, "-" }, true
		end,
	},
	nix = {
		"nix-instantiate",
		parse_nix,
		function(path)
			return { "nix-instantiate", "--parse", path }, false
		end,
	},
	markdown = {
		"markdownlint",
		parse_markdownlint,
		function(path)
			return { "markdownlint", "--json", path }, false
		end,
	},
}

local function collect_output(result)
	local output = result.stdout or ""
	if result.stderr and result.stderr ~= "" then
		output = output .. "\n" .. result.stderr
	end
	return output
end

---Run the configured external linter for a buffer and publish its diagnostics.
---@param buf? integer Buffer to lint; defaults to the current buffer.
function M.run(buf)
	buf = buf or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_buf_is_loaded(buf) then
		return
	end
	local path = buffer_path(buf)
	local config = linters[vim.bo[buf].filetype]
	if not path or not config then
		vim.diagnostic.reset(namespace, buf)
		return
	end
	local executable, parse, command = unpack(config)
	if vim.fn.executable(executable) ~= 1 then
		vim.diagnostic.reset(namespace, buf)
		return
	end

	requests[buf] = (requests[buf] or 0) + 1
	local request = requests[buf]
	local changedtick = vim.api.nvim_buf_get_changedtick(buf)
	local argv, use_stdin = command(path)
	local options = { text = true }
	if use_stdin then
		options.stdin = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
	end

	vim.system(argv, options, function(result)
		vim.schedule(function()
			if not vim.api.nvim_buf_is_valid(buf) or requests[buf] ~= request then
				return
			end
			if vim.api.nvim_buf_get_changedtick(buf) ~= changedtick then
				return
			end
			local output = collect_output(result)
			local diagnostics = executable == "nix-instantiate" and result.code == 0 and {} or parse(output)
			if #diagnostics == 0 and result.code ~= 0 then
				local detail = output:match("[^\r\n]+") or (executable .. " exited with status " .. result.code)
				diagnostics[1] = message(detail, 1, 1, vim.diagnostic.severity.ERROR, executable)
			end
			for _, diagnostic in ipairs(diagnostics) do
				diagnostic.source = executable
			end
			vim.diagnostic.set(namespace, buf, diagnostics, { underline = true, signs = true, virtual_text = false })
		end)
	end)
end

---Register automatic post-save linting and the manual `:NazoLint` command.
function M.setup()
	local group = vim.api.nvim_create_augroup("NazoVimLint", { clear = true })
	vim.api.nvim_create_autocmd("BufWritePost", {
		group = group,
		callback = function(event)
			M.run(event.buf)
		end,
	})
	vim.api.nvim_create_autocmd("BufDelete", {
		group = group,
		callback = function(event)
			requests[event.buf] = nil
		end,
	})
	vim.api.nvim_create_user_command("NazoLint", function()
		M.run()
	end, { desc = "Run the configured external linter" })
	vim.keymap.set("n", "<leader>ll", M.run, { desc = "Lint buffer" })
end

return M
