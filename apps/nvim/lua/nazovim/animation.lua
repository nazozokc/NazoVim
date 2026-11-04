local M = {}

local playback
local ramp = " .:-=+*#%@"

local function generated_frame(index, width, height)
	local lines = {}
	local phase = index * 0.14
	local sine, cosine = math.sin(phase), math.cos(phase)
	local scale = math.max(1, math.min(width, height * 2))
	local mid_x, mid_y = (width + 1) / 2, (height + 1) / 2
	for row = 1, height do
		local chars = {}
		for col = 1, width do
			local x = (col - mid_x) / scale * 2
			local y = (row - mid_y) / scale * 2
			local radius = math.sqrt(x * x + y * y)
			local angle = math.atan2 and math.atan2(y, x) or math.atan(y / (x == 0 and 0.0001 or x))
			local drift = x * cosine - y * sine
			local wave = math.sin(radius * 19 - phase * 1.7 + angle * 4)
				+ math.cos(drift * 15 + phase * 0.8)
				+ math.sin((x * sine + y * cosine) * 11 - phase)
			local shade = math.floor((wave + 3) / 6 * #ramp) + 1
			shade = math.max(1, math.min(#ramp, shade))
			chars[col] = ramp:sub(shade, shade)
		end
		lines[row] = table.concat(chars)
	end
	return lines
end

local function as_lines(frame)
	if type(frame) == "string" then
		return vim.split(frame, "\n", { plain = true })
	elseif type(frame) == "table" then
		local lines = {}
		for _, line in ipairs(frame) do
			lines[#lines + 1] = tostring(line)
		end
		return lines
	end
	return nil
end

local function render()
	local current = playback
	if not current or not vim.api.nvim_win_is_valid(current.win) or not vim.api.nvim_buf_is_valid(current.buf) then
		M.stop(false)
		return
	end
	if vim.api.nvim_win_get_buf(current.win) ~= current.buf then
		M.stop(false)
		return
	end
	local lines
	if current.frames then
		lines = as_lines(current.frames[current.index])
		current.index = current.index % #current.frames + 1
	else
		local width = math.max(12, math.min(vim.api.nvim_win_get_width(current.win) - 2, 100))
		local height = math.max(5, math.min(vim.api.nvim_win_get_height(current.win) - 1, 36))
		lines = generated_frame(current.index, width, height)
		current.index = current.index + 1
	end
	if not lines then
		M.stop(true)
		vim.notify("Animation frame must be a string or list of lines", vim.log.levels.ERROR, {
			title = "NazoVim Animation",
		})
		return
	end
	vim.bo[current.buf].modifiable = true
	vim.api.nvim_buf_set_lines(current.buf, 0, -1, false, lines)
	vim.bo[current.buf].modifiable = false
	vim.api.nvim_win_set_cursor(current.win, { 1, 0 })
end

---Stop animation and optionally restore the buffer and window view from before playback.
function M.stop(restore)
	local current = playback
	if not current then
		return
	end
	playback = nil
	current.timer:stop()
	current.timer:close()
	if vim.api.nvim_win_is_valid(current.win) then
		if vim.api.nvim_win_get_buf(current.win) == current.buf then
			local target = restore ~= false and vim.api.nvim_buf_is_valid(current.previous_buf) and current.previous_buf
				or vim.api.nvim_create_buf(true, false)
			vim.api.nvim_win_set_buf(current.win, target)
		end
		for option, value in pairs(current.window_options) do
			vim.wo[current.win][option] = value
		end
	end
	if vim.api.nvim_buf_is_valid(current.buf) then
		pcall(vim.api.nvim_buf_delete, current.buf, { force = true })
	end
end

---Play supplied text frames, or a generated abstract animation when frames are omitted.
function M.play(frames, fps)
	M.stop(true)
	if frames ~= nil and (type(frames) ~= "table" or #frames == 0) then
		vim.notify("Animation frames must be a non-empty list", vim.log.levels.ERROR, {
			title = "NazoVim Animation",
		})
		return
	end
	local win = vim.api.nvim_get_current_win()
	local previous_buf = vim.api.nvim_win_get_buf(win)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].modifiable = false
	local options = { "number", "relativenumber", "wrap", "cursorline", "signcolumn" }
	local window_options = {}
	for _, option in ipairs(options) do
		window_options[option] = vim.wo[win][option]
	end
	playback = {
		win = win,
		buf = buf,
		previous_buf = previous_buf,
		window_options = window_options,
		frames = frames,
		index = 1,
		timer = vim.uv.new_timer(),
	}
	vim.api.nvim_win_set_buf(win, buf)
	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].wrap = false
	vim.wo[win].cursorline = false
	vim.wo[win].signcolumn = "no"
	vim.keymap.set("n", "q", function()
		M.stop(true)
	end, { buffer = buf, nowait = true, silent = true, desc = "Stop animation" })
	vim.keymap.set("n", "<Esc>", function()
		M.stop(true)
	end, { buffer = buf, nowait = true, silent = true, desc = "Stop animation" })
	local interval = math.max(20, math.floor(1000 / math.max(1, math.min(60, tonumber(fps) or 12))))
	playback.timer:start(0, interval, vim.schedule_wrap(render))
end

---Register animation playback and stop commands.
function M.setup()
	vim.api.nvim_create_user_command("NazoAnimation", function(options)
		local fps = options.args ~= "" and tonumber(options.args) or nil
		M.play(nil, fps)
	end, { nargs = "?", desc = "Play an original procedural animation" })
	vim.api.nvim_create_user_command("NazoAnimationStop", function()
		M.stop(true)
	end, { desc = "Stop animation playback" })
end

return M
