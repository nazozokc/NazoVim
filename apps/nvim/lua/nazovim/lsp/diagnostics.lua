local M = {}

local severity_filter = nil -- nil = all, or vim.diagnostic.severity.ERROR etc.

local all_severities = {
	vim.diagnostic.severity.ERROR,
	vim.diagnostic.severity.WARN,
	vim.diagnostic.severity.INFO,
	vim.diagnostic.severity.HINT,
}

local function current_severity()
	return severity_filter
end

---Configure diagnostics with virtual lines on current line and restrained virtual text.
function M.setup()
	vim.diagnostic.config({
		virtual_text = {
			severity = { min = vim.diagnostic.severity.ERROR },
			prefix = "●",
			source = "if_many",
		},
		virtual_lines = { current_line = true },
		severity_sort = true,
		update_in_insert = false,
		float = { border = "rounded", source = "if_many", header = "" },
		signs = {
			text = {
				[vim.diagnostic.severity.ERROR] = "✗",
				[vim.diagnostic.severity.WARN] = "⚠",
				[vim.diagnostic.severity.INFO] = "ℹ",
				[vim.diagnostic.severity.HINT] = "○",
			},
		},
	})

	vim.keymap.set("n", "[d", function()
		M.goto_prev()
	end, { desc = "Prev diagnostic" })
	vim.keymap.set("n", "]d", function()
		M.goto_next()
	end, { desc = "Next diagnostic" })
	vim.keymap.set("n", "<leader>e", function()
		M.open_float()
	end, { desc = "Show diagnostic" })
	vim.keymap.set("n", "<leader>de", function()
		M.toggle_errors_only()
	end, { desc = "Toggle errors only" })
end

---Jump to the previous diagnostic, respecting the current severity filter.
function M.goto_prev()
	vim.diagnostic.jump({ count = -1, severity = current_severity(), float = true })
end

---Jump to the next diagnostic, respecting the current severity filter.
function M.goto_next()
	vim.diagnostic.jump({ count = 1, severity = current_severity(), float = true })
end

---Open a floating window for diagnostics on the current line.
function M.open_float()
	vim.diagnostic.open_float({ border = "rounded", source = "if_many" })
end

---Toggle between showing all diagnostics and errors only.
---The filter applies to the signs, virtual text and `]d` / `[d` jumps alike.
function M.toggle_errors_only()
	if severity_filter == vim.diagnostic.severity.ERROR then
		severity_filter = nil
		vim.diagnostic.config({ severity = all_severities })
		vim.notify("Diagnostics: all severities", vim.log.levels.INFO, { title = "NazoVim LSP" })
	else
		severity_filter = vim.diagnostic.severity.ERROR
		vim.diagnostic.config({ severity = { vim.diagnostic.severity.ERROR } })
		vim.notify("Diagnostics: errors only", vim.log.levels.INFO, { title = "NazoVim LSP" })
	end
end

return M
