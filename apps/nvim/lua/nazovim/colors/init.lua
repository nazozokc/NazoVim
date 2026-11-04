local M = {}

local parse = require("nazovim.colors.parse").parse
local ns = vim.api.nvim_create_namespace("NazoColors")
local highlights, highlight_count, variables = {}, 0, {}
local enabled, active, lifecycle_group = true, false, nil

local function group(color)
	if highlights[color] then
		return highlights[color]
	end
	-- Avoid accumulating unbounded global highlight groups in generated palettes.
	if highlight_count >= 512 then
		return
	end
	local name = string.format("NazoColor%06x", color)
	local r, g, b = math.floor(color / 65536), math.floor(color / 256) % 256, color % 256
	vim.api.nvim_set_hl(0, name, { bg = color, fg = (r * 299 + g * 587 + b * 114) > 128000 and 0x16161d or 0xffffff })
	highlights[color] = name
	highlight_count = highlight_count + 1
	return name
end

local function css_variables(buf)
	local tick = vim.api.nvim_buf_get_changedtick(buf)
	if variables[buf] and variables[buf].tick == tick then
		return variables[buf].values
	end
	local values = {}
	if
		vim.api.nvim_buf_line_count(buf) <= 5000
		and vim.api.nvim_buf_get_offset(buf, vim.api.nvim_buf_line_count(buf)) <= 200000
	then
		for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
			for name, value in line:gmatch("(%-%-[%w_-]+)%s*:%s*([^;}]+)") do
				values[name] = parse(value)
			end
		end
	end
	variables[buf] = { tick = tick, values = values }
	return values
end

local function render(buf, rows)
	local vars = css_variables(buf)
	for row in pairs(rows) do
		local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
		if #line <= 4096 then
			local used = {}
			local function add(first, last, color)
				if not color or used[first] then
					return
				end
				local hl = group(color)
				if not hl then
					return
				end
				for col = first, last do
					used[col] = true
				end
				vim.api.nvim_buf_set_extmark(
					buf,
					ns,
					row - 1,
					first - 1,
					{ end_col = last, hl_group = hl, priority = 130 }
				)
			end
			for first, value, after in line:gmatch("()(#%x+)()") do
				add(first, after - 1, parse(value))
			end
			for first, value, after in line:gmatch("()(%a+%b())()") do
				local variable = value:match("^var%(%s*(%-%-[%w_-]+)%s*%)$")
				add(first, after - 1, variable and vars[variable] or parse(value))
			end
			for first, value, after in line:gmatch("()%f[%a]([%a]+)%f[^%w_-]()") do
				add(first, after - 1, parse(value))
			end
		end
	end
end

---Decorate visible color literals, with bounded CSS-variable and highlight caches.
function M.setup()
	if not enabled or active then
		return
	end
	active = true
	lifecycle_group = vim.api.nvim_create_augroup("NazoColorCache", { clear = true })
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = lifecycle_group,
		callback = function()
			highlights = {}
			highlight_count = 0
		end,
	})
	vim.api.nvim_create_autocmd("BufWipeout", {
		group = lifecycle_group,
		callback = function(args)
			variables[args.buf] = nil
		end,
	})
	require("nazovim.ui").decorate("NazoColors", ns, render)
end

---Stop color-literal previews and clear their extmarks.
function M.disable()
	enabled = false
	if lifecycle_group then
		pcall(vim.api.nvim_del_augroup_by_id, lifecycle_group)
		lifecycle_group = nil
	end
	pcall(vim.api.nvim_del_augroup_by_name, "NazoColors")
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
		end
	end
	active = false
end

---Start color-literal previews.
function M.enable()
	enabled = true
	M.setup()
end

M.parse = parse

return M
