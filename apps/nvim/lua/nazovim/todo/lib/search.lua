local kinds = require("nazovim.todo.lib.kinds")

local M = {}
local job

---Search the project asynchronously and publish TODO candidates to quickfix/location list.
function M.search(loclist)
	if vim.fn.executable("rg") == 0 then
		vim.notify("Todo search requires ripgrep (rg)", vim.log.levels.ERROR)
		return
	end
	if job then
		job:kill(15)
	end
	local words = vim.tbl_keys(kinds)
	table.sort(words)
	local cwd, win = vim.fn.getcwd(), vim.api.nvim_get_current_win()
	local current
	current = vim.system(
		{ "rg", "--json", "--glob", "!.git", "--", "\\b(" .. table.concat(words, "|") .. "):", "." },
		{ cwd = cwd, text = true },
		function(result)
			vim.schedule(function()
				if job ~= current then
					return
				end
				job = nil
				if result.code > 1 then
					vim.notify(result.stderr, vim.log.levels.ERROR)
					return
				end
				local items = {}
				for line in result.stdout:gmatch("[^\n]+") do
					local entry = vim.json.decode(line)
					if entry.type == "match" and entry.data.path.text and entry.data.lines.text then
						for _, match in ipairs(entry.data.submatches) do
							items[#items + 1] = {
								filename = cwd .. "/" .. entry.data.path.text,
								lnum = entry.data.line_number,
								col = match.start + 1,
								text = vim.trim(entry.data.lines.text),
							}
						end
					end
				end
				if loclist then
					if vim.api.nvim_win_is_valid(win) then
						vim.fn.setloclist(win, {}, "r", { title = "TODO", items = items })
						vim.api.nvim_win_call(win, function()
							vim.cmd.lopen()
						end)
					end
				else
					vim.fn.setqflist({}, "r", { title = "TODO", items = items })
					vim.cmd.copen()
				end
			end)
		end
	)
	job = current
end

return M
