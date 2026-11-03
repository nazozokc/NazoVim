local M = {}

local timeout_ms = 1000
local formatters = {
	lua = {
		"stylua",
		function()
			return { "stylua", "-" }
		end,
	},
	javascript = {
		"prettier",
		function(path)
			return { "prettier", "--stdin-filepath", path }
		end,
	},
	javascriptreact = {
		"prettier",
		function(path)
			return { "prettier", "--stdin-filepath", path }
		end,
	},
	typescript = {
		"prettier",
		function(path)
			return { "prettier", "--stdin-filepath", path }
		end,
	},
	typescriptreact = {
		"prettier",
		function(path)
			return { "prettier", "--stdin-filepath", path }
		end,
	},
	json = {
		"prettier",
		function(path)
			return { "prettier", "--stdin-filepath", path }
		end,
	},
	jsonc = {
		"prettier",
		function(path)
			return { "prettier", "--stdin-filepath", path }
		end,
	},
	html = {
		"prettier",
		function(path)
			return { "prettier", "--stdin-filepath", path }
		end,
	},
	css = {
		"prettier",
		function(path)
			return { "prettier", "--stdin-filepath", path }
		end,
	},
	scss = {
		"prettier",
		function(path)
			return { "prettier", "--stdin-filepath", path }
		end,
	},
	markdown = {
		"prettier",
		function(path)
			return { "prettier", "--stdin-filepath", path }
		end,
	},
	yaml = {
		"prettier",
		function(path)
			return { "prettier", "--stdin-filepath", path }
		end,
	},
	python = {
		"black",
		function(path)
			return { "black", "--quiet", "--stdin-filename", path, "-" }
		end,
	},
	c = {
		"clang-format",
		function(path)
			return { "clang-format", "--assume-filename=" .. path }
		end,
	},
	cpp = {
		"clang-format",
		function(path)
			return { "clang-format", "--assume-filename=" .. path }
		end,
	},
	nix = {
		"nixfmt",
		function()
			return { "nixfmt" }
		end,
	},
	ruby = {
		"rubocop",
		function(path)
			return { "rubocop", "--autocorrect", "--stderr", "--stdin", path }
		end,
	},
}

local function buffer_text(buf)
	local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
	if vim.bo[buf].endofline then
		text = text .. "\n"
	end
	return text
end

local function replace_buffer(buf, output)
	local endofline = output:sub(-1) == "\n"
	local lines = vim.split(output, "\n", { plain = true })
	if endofline then
		table.remove(lines)
	end
	if #lines == 0 then
		lines = { "" }
	end
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].endofline = endofline
end

local function apply_result(buf, result, formatter)
	if not vim.api.nvim_buf_is_valid(buf) then
		return false
	end
	if result.code ~= 0 then
		local details = vim.trim(result.stderr or "")
		if details == "" then
			details = formatter .. " exited with status " .. result.code
		end
		vim.notify(details, vim.log.levels.WARN, { title = "NazoVim Format" })
		return false
	end
	replace_buffer(buf, result.stdout or "")
	return true
end

local function run_external(buf, async)
	local path = vim.api.nvim_buf_get_name(buf)
	if path == "" then
		return false
	end
	local config = formatters[vim.bo[buf].filetype]
	if not config or vim.fn.executable(config[1]) ~= 1 then
		return false
	end
	local command = config[2](vim.fn.fnamemodify(path, ":p"))
	local input = buffer_text(buf)
	local changedtick = vim.api.nvim_buf_get_changedtick(buf)
	if async then
		vim.system(command, { stdin = input, text = true }, function(result)
			vim.schedule(function()
				if not vim.api.nvim_buf_is_valid(buf) then
					return
				end
				if vim.api.nvim_buf_get_changedtick(buf) ~= changedtick then
					vim.notify("Buffer changed while formatting; discarded stale result", vim.log.levels.INFO, {
						title = "NazoVim Format",
					})
					return
				end
				apply_result(buf, result, config[1])
			end)
		end)
		return true
	end
	local process = vim.system(command, { stdin = input, text = true })
	local result = process:wait(timeout_ms)
	if result.code == 124 then
		vim.notify(config[1] .. " exceeded the " .. timeout_ms .. "ms format timeout", vim.log.levels.WARN, {
			title = "NazoVim Format",
		})
		return true
	end
	apply_result(buf, result, config[1])
	return true
end

---Format a buffer with its external formatter or attached LSP client.
---@param options? {bufnr?: integer, async?: boolean}
function M.format(options)
	options = options or {}
	local buf = options.bufnr or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_buf_is_loaded(buf) or vim.bo[buf].buftype ~= "" then
		return
	end
	local async = options.async == true
	if run_external(buf, async) then
		return
	end
	vim.lsp.buf.format({ bufnr = buf, async = async, timeout_ms = timeout_ms })
end

---Install format-on-save and the manual `<leader>f` mapping.
function M.setup()
	local group = vim.api.nvim_create_augroup("NazoFormat", { clear = true })
	vim.api.nvim_create_autocmd("BufWritePre", {
		group = group,
		callback = function(event)
			M.format({ bufnr = event.buf, async = false })
		end,
	})
	vim.keymap.set("n", "<leader>f", function()
		M.format({ async = true })
	end, { desc = "Format buffer" })
end

return M
