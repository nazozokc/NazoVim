local M = {}

local group = "nazo-marks"

local function mark_letter(mark)
	return mark:match("^'([a-zA-Z])$")
end

---Refresh the mark signs for one buffer.
function M.update(buf)
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	vim.fn.sign_unplace(group, { buffer = buf })
	for _, item in ipairs(vim.fn.getmarklist(buf)) do
		local letter = mark_letter(item.mark)
		if letter and item.pos and item.pos[2] and item.pos[2] > 0 then
			vim.fn.sign_place(
				1000 + letter:byte(),
				group,
				"NazoMark",
				buf,
				{ lnum = item.pos[2], priority = 10, text = letter }
			)
		end
	end
end

---All marks as quickfix items.
function M.list()
	local result = {}
	for _, item in ipairs(vim.fn.getmarklist()) do
		local letter = mark_letter(item.mark)
		local pos = item.pos
		if letter and pos and pos[1] and vim.api.nvim_buf_is_valid(pos[1]) and pos[2] > 0 then
			local filename = vim.api.nvim_buf_get_name(pos[1])
			if filename ~= "" then
				local line = vim.api.nvim_buf_get_lines(pos[1], pos[2] - 1, pos[2], false)[1] or ""
				result[#result + 1] = {
					filename = filename,
					lnum = pos[2],
					col = pos[3] + 1,
					text = letter .. ": " .. vim.trim(line),
				}
			end
		end
	end
	table.sort(result, function(a, b)
		if a.filename == b.filename then
			return a.lnum < b.lnum
		end
		return a.filename < b.filename
	end)
	return result
end

---Open the mark list in the quickfix window.
function M.qf()
	local items = M.list()
	if #items == 0 then
		vim.notify("No marks", vim.log.levels.INFO)
		return
	end
	vim.fn.setqflist(items, "r")
	vim.fn.setqflist({}, "a", { title = "Marks" })
	vim.cmd.copen()
end

---Jump to the next/previous mark in the current buffer.
function M.jump(direction)
	local buf = vim.api.nvim_get_current_buf()
	local current = vim.api.nvim_win_get_cursor(0)[1]
	local lines = {}
	for _, item in ipairs(vim.fn.getmarklist(buf)) do
		if mark_letter(item.mark) and item.pos[2] > 0 then
			lines[#lines + 1] = item.pos[2]
		end
	end
	table.sort(lines)
	local target
	if direction > 0 then
		for _, lnum in ipairs(lines) do
			if lnum > current then
				target = lnum
				break
			end
		end
		target = target or lines[1]
	else
		for i = #lines, 1, -1 do
			if lines[i] < current then
				target = lines[i]
				break
			end
		end
		target = target or lines[#lines]
	end
	if target then
		vim.api.nvim_win_set_cursor(0, { target, 0 })
	end
end

function M.setup()
	vim.fn.sign_define("NazoMark", { text = "", texthl = "NazoMark" })
	vim.api.nvim_set_hl(0, "NazoMark", { link = "Special", default = true })
	vim.api.nvim_create_user_command("Marks", M.qf, { desc = "List marks" })
	vim.keymap.set("n", "]m", function()
		M.jump(1)
	end, { desc = "Next mark" })
	vim.keymap.set("n", "[m", function()
		M.jump(-1)
	end, { desc = "Previous mark" })
	local augroup = vim.api.nvim_create_augroup("NazoMarks", { clear = true })
	vim.api.nvim_create_autocmd({ "BufEnter", "CursorHold", "TextChanged", "BufWritePost" }, {
		group = augroup,
		callback = function(args)
			M.update(args.buf)
		end,
	})
end

return M
