local M = {}

---Directories that hold `parser/<lang>.so` and `queries/<lang>/*.scm`.
---The flake devShell and the Nix package export them through
---`NAZOVIM_TREESITTER_DIR` (a colon separated list).
---@return string[]
function M.directories()
	local result = {}
	for directory in (vim.env.NAZOVIM_TREESITTER_DIR or ""):gmatch("[^:]+") do
		if vim.fn.isdirectory(directory) == 1 then
			result[#result + 1] = directory
		end
	end
	return result
end

---Return the parser file Neovim would load for a language.
---@param language string
---@return string?
local function parser_file(language)
	return vim.api.nvim_get_runtime_file("parser/" .. language .. ".so", false)[1]
end

---Return whether a parser for the language is reachable on runtimepath.
---@param language string
---@return boolean
function M.available(language)
	if type(language) ~= "string" or language == "" then
		return false
	end
	return parser_file(language) ~= nil
end

---Resolve the treesitter language of a buffer from its filetype.
---@param buf? integer
---@return string?
function M.language(buf)
	buf = buf or vim.api.nvim_get_current_buf()
	local filetype = vim.bo[buf].filetype
	if filetype == "" then
		return nil
	end
	local ok, language = pcall(vim.treesitter.language.get_lang, filetype)
	return (ok and language) or filetype
end

local enabled = {}

---Start treesitter highlighting and indentation for a buffer when its parser
---is available. Returns the language, or nil when nothing was attached.
---@param buf? integer
---@return string?
function M.attach(buf)
	buf = buf or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= "" then
		return nil
	end
	if vim.b[buf].nazovim_treesitter then
		return vim.b[buf].nazovim_treesitter
	end
	local language = M.language(buf)
	if not language or not M.available(language) then
		return nil
	end
	local limit = tonumber(vim.g.nazovim_treesitter_max_lines) or 50000
	if vim.api.nvim_buf_line_count(buf) > limit then
		return nil
	end
	local ok = pcall(vim.treesitter.start, buf, language)
	if not ok then
		return nil
	end
	enabled[language] = (enabled[language] or 0) + 1
	vim.b[buf].nazovim_treesitter = language
	return language
end

---Return the language attached to a buffer.
---@param buf? integer
---@return string?
function M.attached(buf)
	return vim.b[buf or vim.api.nvim_get_current_buf()].nazovim_treesitter
end

---Return the languages attached in this session, sorted.
---@return string[]
function M.enabled()
	local result = {}
	for language in pairs(enabled) do
		result[#result + 1] = language
	end
	table.sort(result)
	return result
end

---Return the languages that have a parser on runtimepath, sorted.
---@return string[]
function M.languages()
	local seen = {}
	for _, file in ipairs(vim.api.nvim_get_runtime_file("parser/*.so", true)) do
		local language = vim.fn.fnamemodify(file, ":t:r")
		seen[language] = true
	end
	local result = {}
	for language in pairs(seen) do
		result[#result + 1] = language
	end
	table.sort(result)
	return result
end

---Report the parsers that are reachable and the languages already attached.
function M.info()
	local lines = { "languages: " .. (#M.languages() > 0 and table.concat(M.languages(), ", ") or "none") }
	local active = M.enabled()
	if #active > 0 then
		lines[#lines + 1] = "attached: " .. table.concat(active, ", ")
	end
	local current = M.attached()
	if current then
		lines[#lines + 1] = "buffer: " .. current
	end
	vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "NazoVim Treesitter" })
end

---Add the grammar directories to runtimepath and attach on every filetype.
function M.setup()
	for _, directory in ipairs(M.directories()) do
		vim.opt.runtimepath:append(directory)
	end

	vim.api.nvim_create_autocmd("FileType", {
		group = vim.api.nvim_create_augroup("NazoTreesitter", { clear = true }),
		desc = "Start treesitter for filetypes that have a parser",
		callback = function(args)
			M.attach(args.buf)
		end,
	})

	vim.api.nvim_create_user_command("NazoTreesitterInfo", M.info, { desc = "Show the treesitter parsers in use" })
end

return M
