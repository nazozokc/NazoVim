local M = {}

local function notify_error(err)
	vim.notify(tostring(err), vim.log.levels.ERROR, { title = "NazoVim" })
end

local function protected(callback)
	local ok, err = pcall(callback)
	if not ok then
		notify_error(err)
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
		notify_error("Usage: Template [name] or Template destination name")
		return
	end
	protected(function()
		template.insert(args.fargs[2] or args.fargs[1], args.fargs[2] and args.fargs[1] or nil)
	end)
end

local function create_project(args)
	if #args.fargs ~= 2 then
		notify_error("Usage: TemplateProject name destination")
		return
	end
	protected(function()
		require("nazovim.template").project(args.fargs[1], args.fargs[2])
	end)
end

---Register template insertion and project generation commands.
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
end

return M
