local M = {}

local ns = vim.api.nvim_create_namespace("NazoWhichKey")
local timer
local pending = ""
local mode = "n"
local popup

local function normalize(keys)
	local ok, result = pcall(vim.fn.keytrans, keys)
	return ok and result or keys
end

---Map mode(1) to a keymap mode. Returns nil when no popup should appear.
local function keymap_mode()
	local current = vim.fn.mode(1)
	if current == "n" then
		return "n"
	end
	if current:sub(1, 2) == "no" then
		return "o"
	end
	if current == "v" or current == "V" or current == "\22" then
		return "x"
	end
	return nil
end

local function maps(mode_name, buf)
	local result = {}
	for _, map in ipairs(vim.api.nvim_get_keymap(mode_name)) do
		result[#result + 1] = map
	end
	if buf and vim.api.nvim_buf_is_valid(buf) then
		for _, map in ipairs(vim.api.nvim_buf_get_keymap(buf, mode_name)) do
			result[#result + 1] = map
		end
	end
	return result
end

local function has_prefix(prefix, mode_name, buf)
	prefix = normalize(prefix)
	for _, map in ipairs(maps(mode_name, buf)) do
		if vim.startswith(normalize(map.lhs), prefix) then
			return true
		end
	end
	return false
end

local function has_mapping(prefix, mode_name, buf)
	prefix = normalize(prefix)
	for _, map in ipairs(maps(mode_name, buf)) do
		if normalize(map.lhs) == prefix then
			return true
		end
	end
	return false
end

local function has_longer_prefix(prefix, mode_name, buf)
	prefix = normalize(prefix)
	for _, map in ipairs(maps(mode_name, buf)) do
		local lhs = normalize(map.lhs)
		if lhs ~= prefix and vim.startswith(lhs, prefix) then
			return true
		end
	end
	return false
end

---List mappings that continue the given prefix. Pure enough to test directly.
function M.items(prefix, mode_name, buf)
	mode_name = mode_name or keymap_mode() or "n"
	buf = buf or vim.api.nvim_get_current_buf()
	local wanted = normalize(prefix)
	local seen, result = {}, {}
	for _, map in ipairs(maps(mode_name, buf)) do
		local lhs = normalize(map.lhs)
		if lhs ~= wanted and vim.startswith(lhs, wanted) then
			local key = lhs:sub(#wanted + 1)
			if key ~= "" and not seen[key] then
				seen[key] = true
				result[#result + 1] = { key = key, desc = map.desc or "" }
			end
		end
	end
	table.sort(result, function(a, b)
		return a.key < b.key
	end)
	return result
end

---Build popup lines and their key width.
function M.render(items)
	local width = 0
	for _, item in ipairs(items) do
		width = math.max(width, vim.fn.strdisplaywidth(item.key))
	end
	local lines = {}
	for _, item in ipairs(items) do
		local padding = string.rep(" ", width - vim.fn.strdisplaywidth(item.key))
		lines[#lines + 1] = item.key .. padding .. (item.desc ~= "" and ("  " .. item.desc) or "")
	end
	return lines, width
end

local function close_popup()
	if popup then
		if popup.win and vim.api.nvim_win_is_valid(popup.win) then
			vim.api.nvim_win_close(popup.win, true)
		end
		if popup.buf and vim.api.nvim_buf_is_valid(popup.buf) then
			vim.api.nvim_buf_delete(popup.buf, { force = true })
		end
	end
	popup = nil
end

---Show pending mappings in a floating window.
function M.show(prefix, mode_name)
	mode_name = mode_name or mode
	local items = M.items(prefix, mode_name)
	if #items == 0 then
		close_popup()
		return
	end
	local lines, key_width = M.render(items)
	if #lines > 20 then
		lines = vim.list_slice(lines, 1, 20)
		lines[#lines + 1] = "…"
	end
	close_popup()
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].bufhidden = "wipe"
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	local width = 0
	for _, line in ipairs(lines) do
		width = math.max(width, vim.fn.strdisplaywidth(line))
	end
	width = math.min(width + 4, math.max(10, vim.o.columns - 2))
	local height = #lines
	local win = vim.api.nvim_open_win(buf, false, {
		relative = "editor",
		anchor = "SW",
		row = vim.o.lines - 2,
		col = 0,
		width = width,
		height = height,
		style = "minimal",
		border = "rounded",
		title = " " .. prefix .. " ",
		title_pos = "left",
		focusable = false,
		zindex = 50,
	})
	vim.wo[win].winhl = "Normal:NazoWhichKeyNormal,FloatBorder:NazoWhichKeyBorder"
	for row = 1, math.min(#lines, #items) do
		vim.api.nvim_buf_set_extmark(buf, ns, row - 1, 0, {
			end_col = math.min(key_width, #lines[row]),
			hl_group = "NazoWhichKeyKey",
		})
	end
	popup = { win = win, buf = buf }
end

local function reset()
	pending = ""
	if timer then
		timer:stop()
	end
	close_popup()
end

local function schedule_show()
	if not timer then
		return
	end
	timer:stop()
	timer:start(
		200,
		0,
		vim.schedule_wrap(function()
			if pending ~= "" then
				M.show(pending, mode)
			end
		end)
	)
end

---Track raw keys and keep the popup in sync.
function M.on_key(key)
	local name = normalize(key)
	if name == "<Esc>" or name == "<C-C>" then
		reset()
		return
	end
	local current = keymap_mode()
	if not current then
		reset()
		return
	end
	mode = current
	local candidate = pending .. name
	local buf = vim.api.nvim_get_current_buf()
	if not has_prefix(candidate, mode, buf) then
		reset()
		return
	end
	pending = candidate
	if has_mapping(pending, mode, buf) and not has_longer_prefix(pending, mode, buf) then
		reset()
		return
	end
	schedule_show()
end

function M.setup()
	if M._attached then
		return
	end
	M._attached = true
	timer = vim.uv.new_timer()
	vim.api.nvim_set_hl(0, "NazoWhichKeyKey", { link = "Identifier", default = true })
	vim.api.nvim_set_hl(0, "NazoWhichKeyDesc", { link = "Comment", default = true })
	vim.api.nvim_set_hl(0, "NazoWhichKeyNormal", { link = "NormalFloat", default = true })
	vim.api.nvim_set_hl(0, "NazoWhichKeyBorder", { link = "FloatBorder", default = true })
	vim.on_key(M.on_key, ns)
	local group = vim.api.nvim_create_augroup("NazoWhichKey", { clear = true })
	vim.api.nvim_create_autocmd("ModeChanged", {
		group = group,
		callback = function()
			if not keymap_mode() then
				reset()
			end
		end,
	})
	vim.api.nvim_create_autocmd({ "WinLeave", "BufLeave", "InsertEnter", "CmdlineEnter", "VimResized" }, {
		group = group,
		callback = reset,
	})
	vim.keymap.set("n", "<leader>?", function()
		M.show(vim.g.mapleader or "\\", "n")
	end, { desc = "Show keymaps" })
end

---Expose the state for tests and integrations.
function M.pending()
	return pending
end

function M.hide()
	reset()
end

return M
