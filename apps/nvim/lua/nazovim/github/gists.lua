local M = {}

local title = "NazoVim GitHub Gists"

local function run(arguments, callback)
	if vim.fn.executable("gh") ~= 1 then
		vim.notify("GitHub CLI (gh) is required", vim.log.levels.ERROR, { title = title })
		return
	end
	vim.system(vim.list_extend({ "gh" }, arguments), { text = true }, function(result)
		vim.schedule(function()
			if result.code ~= 0 then
				local message = vim.trim(result.stderr or "")
				vim.notify(
					message ~= "" and message or "GitHub CLI command failed",
					vim.log.levels.ERROR,
					{ title = title }
				)
				return
			end
			callback(result.stdout or "")
		end)
	end)
end

local function decode(output)
	local ok, value = pcall(vim.json.decode, output)
	if ok and type(value) == "table" then
		return value
	end
	return nil
end

local function gist_url(gist)
	return "https://gist.github.com/" .. gist.id
end

local function gist_line(gist)
	local files = table.concat(gist.files or {}, ", ")
	local visibility = gist.public and "public" or "secret"
	local updated = (gist.updated_at or ""):sub(1, 10)
	return string.format("%-7s %s %-30s %s", visibility, updated, files, gist.description or "")
end

local function show_gists(gists)
	local lines = {
		string.format("# Gists · %d", #gists),
		"Actions: <CR> open · y copy URL · q close",
		"",
	}
	local lookup = {}
	for _, gist in ipairs(gists) do
		lines[#lines + 1] = gist_line(gist)
		lookup[#lines] = gist
	end
	if #gists == 0 then
		lines[#lines + 1] = "No gists were returned."
	end
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(buf, "NazoGitHub://gists/" .. buf)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = "markdown"
	vim.bo[buf].swapfile = false
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.cmd("botright split")
	vim.api.nvim_win_set_buf(0, buf)
	vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, desc = "Close gist list" })
	local function current()
		return lookup[vim.api.nvim_win_get_cursor(0)[1]]
	end
	vim.keymap.set("n", "<CR>", function()
		local gist = current()
		if gist then
			vim.ui.open(gist_url(gist))
		end
	end, { buffer = buf, desc = "Open gist" })
	vim.keymap.set("n", "gx", function()
		local gist = current()
		if gist then
			vim.ui.open(gist_url(gist))
		end
	end, { buffer = buf, desc = "Open gist" })
	vim.keymap.set("n", "y", function()
		local gist = current()
		if gist then
			vim.fn.setreg('"', gist_url(gist))
			vim.notify("Gist URL copied", vim.log.levels.INFO, { title = title })
		end
	end, { buffer = buf, desc = "Copy gist URL" })
end

function M.open()
	run({
		"api",
		"--paginate",
		"gists?per_page=100",
		"--jq",
		".[] | {id: .id, description: .description, public: .public, updated_at: .updated_at, files: (.files | keys)}",
	}, function(output)
		local gists = {}
		for _, line in ipairs(vim.split(vim.trim(output), "\n", { plain = true })) do
			local gist = line ~= "" and decode(line) or nil
			if gist and gist.id then
				gists[#gists + 1] = gist
			end
		end
		show_gists(gists)
	end)
end

function M.setup()
	vim.api.nvim_create_user_command("NazoGitHubGists", M.open, { desc = "List GitHub gists" })
	vim.keymap.set("n", "<leader>oG", M.open, { desc = "GitHub Gists" })
end

return M
