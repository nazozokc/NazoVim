local M = {}

local title = "NazoVim Zen"
local active = false
local saved = nil

local options = {
	"number",
	"relativenumber",
	"signcolumn",
	"laststatus",
	"showmode",
	"ruler",
	"winbar",
}

local function notify(message)
	vim.notify(message, vim.log.levels.INFO, { title = title })
end

local function enter()
	saved = {}
	for _, name in ipairs(options) do
		saved[name] = vim.opt[name]:get()
	end
	saved.diagnostics = vim.diagnostic.is_enabled()
	vim.opt.number = false
	vim.opt.relativenumber = false
	vim.opt.signcolumn = "no"
	vim.opt.laststatus = 0
	vim.opt.showmode = false
	vim.opt.ruler = false
	vim.opt.winbar = ""
	vim.diagnostic.enable(false)
	active = true
end

local function leave()
	if saved then
		for _, name in ipairs(options) do
			vim.opt[name] = saved[name]
		end
		vim.diagnostic.enable(saved.diagnostics ~= false)
	end
	saved = nil
	active = false
end

---Toggle a distraction-free view that hides numbers, signs, statusline and diagnostics.
function M.toggle()
	if active then
		leave()
		notify("Zen mode off")
		return
	end
	enter()
	notify("Zen mode on")
end

---Return whether zen mode is currently active.
function M.enabled()
	return active
end

function M.setup()
	vim.api.nvim_create_user_command("NazoZen", M.toggle, { desc = "Toggle zen mode" })
	vim.keymap.set("n", "<leader>z", M.toggle, { desc = "Zen Mode" })
end

return M
