local M = {}

local namespace = vim.api.nvim_create_namespace("NazoDashboard")
local recent_limit = 8
local autokeys = "asdfghjkl"

local header = {
	" █   █  ███  █████  ███  █   █ ███ █   █",
	" ██  █ █   █     █ █   █ █   █  █  ██ ██",
	" █ █ █ █   █    █  █   █ █   █  █  █ █ █",
	" █  ██ █████   █   █   █ █   █  █  █   █",
	" █   █ █   █  █    █   █  █ █   █  █   █",
	" █   █ █   █ █     █   █  █ █   █  █   █",
	" █   █ █   █ █████  ███    █   ███ █   █",
}

local actions = {
	{
		key = "e",
		desc = "New file",
		run = function()
			vim.cmd.enew()
		end,
	},
	{
		key = "f",
		desc = "Find files",
		run = function()
			require("nazovim.picker").files()
		end,
	},
	{
		key = ".",
		desc = "Browse files",
		run = function()
			require("nazovim.file_browser").open(vim.fn.getcwd())
		end,
	},
	{
		key = "r",
		desc = "Recent files",
		run = function()
			require("nazovim.picker").recent()
		end,
	},
	{
		key = "z",
		desc = "Plugins",
		run = function()
			vim.cmd("NazoPlug")
		end,
	},
	{
		key = "q",
		desc = "Quit",
		run = function()
			vim.cmd.quit()
		end,
	},
}

local function highlight(name, link)
	vim.api.nvim_set_hl(0, name, { link = link, default = true })
end

local function center(text)
	local width = vim.o.columns
	local pad = math.max(0, math.floor((width - vim.fn.strdisplaywidth(text)) / 2))
	return string.rep(" ", pad) .. text
end

local function recent_files()
	local items, seen = {}, {}
	for _, path in ipairs(vim.v.oldfiles) do
		if #items >= recent_limit then
			break
		end
		if path ~= "" and not seen[path] and vim.fn.filereadable(path) == 1 then
			seen[path] = true
			items[#items + 1] = path
		end
	end
	return items
end

local function render(buf)
	local lines, lookup, sections = {}, {}, {}
	local function add(text, group)
		lines[#lines + 1] = text
		if group then
			sections[#sections + 1] = { line = #lines - 1, group = group }
		end
	end

	for _, line in ipairs(header) do
		add(center(line), "NazoDashboardHeader")
	end
	add("")
	add(center("a neovim distribution"), "NazoDashboardComment")
	add("")

	add("  Recent Files", "NazoDashboardSection")
	local files = recent_files()
	if #files == 0 then
		add("  No recent files", "NazoDashboardComment")
	end
	for index, path in ipairs(files) do
		local key = autokeys:sub(index, index)
		add(string.format("  %s  %s", key, vim.fn.fnamemodify(path, ":~:.")))
		lookup[#lines] = { path = path }
		vim.keymap.set("n", key, function()
			vim.cmd.edit({ args = { path } })
		end, { buffer = buf, desc = "Open " .. path })
	end
	add("")

	add("  Keymaps", "NazoDashboardSection")
	for _, action in ipairs(actions) do
		add(string.format("  %s  %s", action.key, action.desc))
		vim.keymap.set("n", action.key, action.run, { buffer = buf, desc = action.desc })
	end

	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	for _, section in ipairs(sections) do
		vim.api.nvim_buf_add_highlight(buf, namespace, section.group, section.line, 0, -1)
	end
	vim.keymap.set("n", "<CR>", function()
		local entry = lookup[vim.api.nvim_win_get_cursor(0)[1]]
		if entry then
			vim.cmd.edit({ args = { entry.path } })
		end
	end, { buffer = buf, desc = "Open recent file" })
end

---Return whether the dashboard should be displayed for the current startup.
function M.should_show()
	if vim.g.nazovim_quickstart_shown then
		return false
	end
	if #vim.api.nvim_list_uis() == 0 then
		return false
	end
	if vim.fn.argc() ~= 0 then
		return false
	end
	if vim.api.nvim_buf_get_name(0) ~= "" or vim.bo.buftype ~= "" or vim.bo.modified then
		return false
	end
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	return #lines == 1 and lines[1] == ""
end

---Open the dashboard in the current window.
function M.show()
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].filetype = "nazodashboard"
	vim.api.nvim_buf_set_name(buf, "NazoDashboard://" .. buf)
	vim.api.nvim_win_set_buf(0, buf)
	highlight("NazoDashboardHeader", "Title")
	highlight("NazoDashboardSection", "Directory")
	highlight("NazoDashboardComment", "Comment")
	render(buf)
end

---Show the dashboard when Neovim started without a file.
function M.maybe_show()
	if M.should_show() then
		M.show()
	end
end

function M.setup()
	vim.api.nvim_create_user_command("NazoDashboard", M.show, { desc = "Open the NazoVim dashboard" })
	vim.api.nvim_create_autocmd("VimEnter", {
		once = true,
		desc = "Show the dashboard when Neovim started without a file",
		callback = function()
			vim.schedule(M.maybe_show)
		end,
	})
end

return M
