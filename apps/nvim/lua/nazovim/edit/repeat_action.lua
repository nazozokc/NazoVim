local M = {}

local previous

local function termcodes(keys)
	return vim.api.nvim_replace_termcodes(keys, true, false, true)
end

---Register the last custom edit as the next `.` action.
---@param callback fun(buf: integer): boolean|nil
---@param buf? integer
function M.set(callback, buf)
	if not buf or buf == 0 then
		buf = vim.api.nvim_get_current_buf()
	end
	previous = {
		callback = callback,
		buf = buf,
		changedtick = vim.api.nvim_buf_get_changedtick(buf),
	}
end

---Replay the last custom edit when no newer buffer edit has superseded it.
---@param count? integer
---@return boolean replayed
function M.replay(count)
	local action = previous
	local buf = vim.api.nvim_get_current_buf()
	if not action or action.buf ~= buf or not vim.api.nvim_buf_is_valid(buf) then
		return false
	end
	if vim.api.nvim_buf_get_changedtick(buf) ~= action.changedtick then
		previous = nil
		return false
	end
	for _ = 1, math.max(1, count or 1) do
		if action.callback(buf) == false then
			break
		end
		action.changedtick = vim.api.nvim_buf_get_changedtick(buf)
	end
	return true
end

---Install dot dispatch for custom actions, falling back to Neovim's native repeat.
function M.setup()
	local group = vim.api.nvim_create_augroup("NazoVimRepeatAction", { clear = true })
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		group = group,
		callback = function(event)
			if
				previous
				and (event.buf ~= previous.buf or vim.api.nvim_buf_get_changedtick(event.buf) ~= previous.changedtick)
			then
				previous = nil
			end
		end,
	})
	vim.keymap.set("n", ".", function()
		local count = vim.v.count1
		if not M.replay(count) then
			local prefix = vim.v.count > 0 and tostring(vim.v.count) or ""
			vim.api.nvim_feedkeys(termcodes(prefix .. "."), "n", false)
		end
		return ""
	end, { expr = true, desc = "Repeat the previous edit" })
end

return M
