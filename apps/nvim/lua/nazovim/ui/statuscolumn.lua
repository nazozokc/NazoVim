local M = {}

-- Signs on the left, then the fold indicator and the line number on the right.
-- The number mirrors 'number' and 'relativenumber' so the built-in column looks
-- like the default one while keeping signs and folds in a single column.
local number = '%{(&number || &relativenumber) ? (&relativenumber ? (v:relnum == 0 ? v:lnum : v:relnum) : v:lnum) : ""}'
local expression = "%s%=%C" .. number .. " "

---Apply the built-in status column.
function M.apply()
	vim.opt.statuscolumn = expression
end

---Return the status column expression used by this module.
function M.expression()
	return expression
end

function M.setup()
	M.apply()
	vim.api.nvim_create_user_command("NazoStatuscolumn", function(command)
		if command.bang then
			vim.opt.statuscolumn = ""
			return
		end
		M.apply()
	end, { bang = true, desc = "Apply the built-in status column (bang resets it)" })
end

return M
