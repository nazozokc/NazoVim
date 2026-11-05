local M = {}

local session_dir = vim.fn.stdpath("state") .. "/sessions"
local save_on_exit = true

local function session_path(directory)
	local cwd = vim.fn.getcwd()
	local name = cwd:gsub("([^%w%._%-])", function(character)
		return string.format("%%%02X", character:byte())
	end) .. ".vim"
	return (directory or session_dir) .. "/" .. name
end

local function session_files()
	local files = vim.fn.glob(session_dir .. "/*.vim", false, true)
	table.sort(files, function(left, right)
		return (vim.fn.getftime(left) or 0) > (vim.fn.getftime(right) or 0)
	end)
	return files
end

---Save the current workspace session.
function M.save()
	if #vim.fn.getbufinfo({ buflisted = 1 }) < 1 then
		return false
	end
	vim.fn.mkdir(session_dir, "p")
	local path = session_path()
	vim.cmd("mksession! " .. vim.fn.fnameescape(path))
	vim.g.nazovim_last_session = path
	return true
end

---Restore the session for the current working directory.
function M.load(path)
	path = path or session_path()
	if vim.fn.filereadable(path) ~= 1 then
		vim.notify("No session found: " .. path, vim.log.levels.INFO, { title = "NazoVim" })
		return false
	end
	vim.cmd("source " .. vim.fn.fnameescape(path))
	return true
end

---Restore the most recently saved session.
function M.load_last()
	local path = vim.g.nazovim_last_session
	if type(path) ~= "string" or vim.fn.filereadable(path) ~= 1 then
		path = session_files()[1]
	end
	return path and M.load(path) or false
end

---Open a simple session chooser using the built-in input UI.
function M.select()
	local files = session_files()
	if #files == 0 then
		vim.notify("No saved sessions", vim.log.levels.INFO, { title = "NazoVim" })
		return
	end
	local labels = {}
	for _, path in ipairs(files) do
		local encoded = vim.fn.fnamemodify(path, ":t:r")
		labels[#labels + 1] = encoded:gsub("%%(%x%x)", function(byte)
			return string.char(tonumber(byte, 16))
		end)
	end
	vim.ui.select(labels, { prompt = "Restore session" }, function(_, index)
		if index then
			M.load(files[index])
		end
	end)
end

---Stop writing the session on exit until the next startup.
function M.stop()
	save_on_exit = false
	vim.notify("Session save disabled for this run", vim.log.levels.INFO, { title = "NazoVim" })
end

---Install session commands, mappings, and exit persistence.
function M.setup()
	local group = vim.api.nvim_create_augroup("NazoVimSession", { clear = true })
	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = group,
		callback = function()
			if save_on_exit then
				M.save()
			end
		end,
	})
	vim.keymap.set("n", "<leader>qs", M.load, { desc = "Restore Session" })
	vim.keymap.set("n", "<leader>qS", M.select, { desc = "Select Session" })
	vim.keymap.set("n", "<leader>ql", M.load_last, { desc = "Restore Last Session" })
	vim.keymap.set("n", "<leader>qd", M.stop, { desc = "Stop Session Save" })
	vim.api.nvim_create_user_command("NazoSessionSave", M.save, { desc = "Save workspace session" })
	vim.api.nvim_create_user_command("NazoSessionLoad", function()
		M.load()
	end, { desc = "Restore workspace session" })
	vim.api.nvim_create_user_command("NazoSessionSelect", M.select, { desc = "Select saved session" })
	vim.api.nvim_create_user_command("NazoSessionStop", M.stop, { desc = "Stop session save on exit" })
end

return M
