local M = {}

local icons = require("nazovim.ui.icons")

local function listed()
	local result = {}
	for _, buf in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
		result[#result + 1] = buf
	end
	return result
end

---Render the buffer tabline.
function M.render()
	local current = vim.api.nvim_get_current_buf()
	local parts = {}
	for _, buf in ipairs(listed()) do
		local label = buf.name ~= "" and vim.fn.fnamemodify(buf.name, ":t") or "[No Name]"
		label = label:gsub("%%", "%%%%")
		local icon = buf.name ~= "" and icons.get_icon(buf.name) or ""
		local name = icon ~= "" and (icon .. " " .. label) or label
		local active = buf.bufnr == current
		local highlight = active and "NazoBufferActive" or "NazoBufferInactive"
		local modified = buf.changed == 1 and " ●" or ""
		parts[#parts + 1] = string.format(
			"%%%d@v:lua.require'nazovim.ui.tabline'.click@%%#%s# %s%s %%#NazoBufferFill#",
			buf.bufnr,
			highlight,
			name,
			modified
		)
	end
	return table.concat(parts)
end

---Switch to a buffer from a tabline click.
function M.click(buf)
	pcall(vim.api.nvim_set_current_buf, buf)
end

local function move(step)
	local buffers = {}
	for _, buf in ipairs(listed()) do
		buffers[#buffers + 1] = buf.bufnr
	end
	if #buffers == 0 then
		return
	end
	local current = vim.api.nvim_get_current_buf()
	local index = 1
	for i, buf in ipairs(buffers) do
		if buf == current then
			index = i
		end
	end
	local target = (index - 1 + step) % #buffers + 1
	vim.api.nvim_set_current_buf(buffers[target])
end

---Close the current buffer without discarding the window.
function M.close()
	local buf = vim.api.nvim_get_current_buf()
	if #listed() <= 1 then
		vim.cmd.enew()
	end
	pcall(vim.cmd, "bdelete " .. buf)
end

function M.next()
	move(1)
end

function M.previous()
	move(-1)
end

function M.setup()
	vim.api.nvim_set_hl(0, "NazoBufferActive", { link = "TabLineSel", default = true })
	vim.api.nvim_set_hl(0, "NazoBufferInactive", { link = "TabLine", default = true })
	vim.api.nvim_set_hl(0, "NazoBufferFill", { link = "TabLineFill", default = true })
	vim.opt.showtabline = 2
	vim.opt.tabline = "%!v:lua.require'nazovim.ui.tabline'.render()"
	local map = vim.keymap.set
	map("n", "<C-PageDown>", M.next, { desc = "Next buffer" })
	map("n", "<C-PageUp>", M.previous, { desc = "Previous buffer" })
	map("n", "<C-A-Tab>", M.next, { desc = "Next buffer" })
	map("n", "<C-A-S-Tab>", M.previous, { desc = "Previous buffer" })
	map("n", "<ScrollWheelDown>", M.next, { desc = "Next buffer" })
	map("n", "<ScrollWheelUp>", M.previous, { desc = "Previous buffer" })
	map("n", "<C-t>", "<cmd>enew<cr>", { desc = "New buffer" })
	map("n", "<C-q>", M.close, { desc = "Close buffer" })
	local group = vim.api.nvim_create_augroup("NazoBufferline", { clear = true })
	vim.api.nvim_create_autocmd({ "BufAdd", "BufDelete", "BufEnter", "TextChanged", "TextChangedI", "BufWritePost" }, {
		group = group,
		callback = function()
			vim.cmd.redrawtabline()
		end,
	})
end

return M
