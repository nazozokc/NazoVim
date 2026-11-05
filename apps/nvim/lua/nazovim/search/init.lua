local M = {}
local ns = vim.api.nvim_create_namespace("NazoSearch")
local enabled, previous = true, nil

---Update the nearest search count without changing the search register or cursor.
function M.update()
	if previous and vim.api.nvim_buf_is_valid(previous) then
		vim.api.nvim_buf_clear_namespace(previous, ns, 0, -1)
	end
	local buf = vim.api.nvim_get_current_buf()
	previous = buf
	local cmdtype = vim.fn.getcmdtype()
	local searching = cmdtype == "/" or cmdtype == "?"
	local pattern = searching and vim.fn.getcmdline() or vim.fn.getreg("/")
	if
		not enabled
		or (vim.v.hlsearch == 0 and not searching)
		or pattern == ""
		or not require("nazovim.lib.ui").normal(buf)
	then
		return
	end
	local ok, count = pcall(vim.fn.searchcount, { pattern = pattern, recompute = 1, maxcount = 9999, timeout = 10 })
	-- Incomplete search expressions are normal while typing / or ?.
	if not ok or not count.total or count.total == 0 then
		return
	end
	local text = string.format("[%d/%d%s]", count.current, count.total, count.incomplete ~= 0 and "+" or "")
	vim.api.nvim_buf_set_extmark(buf, ns, vim.api.nvim_win_get_cursor(0)[1] - 1, 0, {
		virt_text = { { text, "Search" } },
		virt_text_pos = "eol",
		priority = 150,
	})
end

---Preserve n/N/*/# semantics and install the search count toggle.
function M.setup()
	local group = vim.api.nvim_create_augroup("NazoSearch", { clear = true })
	local update = require("nazovim.lib.ui").throttle(30, M.update)
	vim.api.nvim_create_autocmd(
		{ "CursorMoved", "BufEnter", "CmdlineLeave", "TextChanged" },
		{ group = group, callback = update }
	)
	vim.api.nvim_create_autocmd("CmdlineChanged", { group = group, pattern = { "/", "?" }, callback = update })
	for _, key in ipairs({ "n", "N", "*", "#" }) do
		vim.keymap.set("n", key, function()
			vim.cmd.normal({ args = { tostring(vim.v.count1) .. key }, bang = true })
			M.update()
		end, { desc = "Search " .. key, silent = true })
	end
	vim.keymap.set("n", "<leader>l", function()
		enabled = not enabled
		M.update()
	end, { desc = "Toggle search count" })
	vim.keymap.set("n", "<leader>h", function()
		vim.cmd.nohlsearch()
		M.update()
	end, { desc = "Clear search highlight" })
end

return M
