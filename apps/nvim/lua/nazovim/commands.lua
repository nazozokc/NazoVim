local M = {}

local function notify(message)
	vim.notify(message, vim.log.levels.ERROR, { title = "NazoVim" })
end

local function protected(callback)
	local ok, err = pcall(callback)
	if not ok then
		notify(tostring(err))
	end
end

local function insert_template(args)
	local template = require("nazovim.template")
	if #args.fargs == 0 then
		local buf = vim.api.nvim_get_current_buf()
		vim.ui.select(template.list(false), { prompt = "Template:" }, function(name)
			if not name or not vim.api.nvim_buf_is_valid(buf) then
				return
			end
			protected(function()
				vim.api.nvim_set_current_buf(buf)
				template.insert(name)
			end)
		end)
		return
	end
	if #args.fargs > 2 then
		notify("Usage: Template [name] or Template destination name")
		return
	end
	protected(function()
		template.insert(args.fargs[2] or args.fargs[1], args.fargs[2] and args.fargs[1] or nil)
	end)
end

local function create_project(args)
	if #args.fargs ~= 2 then
		notify("Usage: TemplateProject name destination")
		return
	end
	protected(function()
		require("nazovim.template").project(args.fargs[1], args.fargs[2])
	end)
end

local function find_todos(loclist)
	return function()
		require("nazovim.todo").search(loclist)
	end
end

---Register every built-in user command. Implementations stay lazily loaded.
function M.setup()
	vim.api.nvim_create_user_command("Template", insert_template, {
		nargs = "*",
		complete = function()
			return require("nazovim.template").list(false)
		end,
		desc = "Insert a file template",
	})
	vim.api.nvim_create_user_command("TemplateProject", create_project, {
		nargs = "+",
		complete = function()
			return require("nazovim.template").list(true)
		end,
		desc = "Create a project from a template",
	})
	vim.api.nvim_create_user_command("ToggleTerm", function(opts)
		require("nazovim.terminal").toggle(opts.count > 0 and opts.count or 1)
	end, { count = true, desc = "Toggle floating terminal" })
	vim.api.nvim_create_user_command("TodoQuickFix", find_todos(false), { desc = "Find project TODOs" })
	vim.api.nvim_create_user_command(
		"TodoLocList",
		find_todos(true),
		{ desc = "Find project TODOs in a location list" }
	)
	vim.api.nvim_create_user_command("TodoTelescope", find_todos(false), { desc = "Find project TODOs (quickfix)" })
	vim.api.nvim_create_user_command("TodoTrouble", find_todos(false), { desc = "Find project TODOs (quickfix)" })
end

return M
