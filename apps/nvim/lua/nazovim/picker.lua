local M = {}

local uv = vim.uv
local MAX_FILES = 50000

local function root_directory()
	return vim.fs.root(0, { ".git", "package.json", "Cargo.toml", "go.mod", "pyproject.toml" }) or vim.fn.getcwd()
end

local function collect_files(root)
	local files = {}
	local function visit(directory, depth)
		if depth > 40 or #files >= MAX_FILES then
			return
		end
		local handle = uv.fs_scandir(directory)
		if not handle then
			return
		end
		while #files < MAX_FILES do
			local name, kind = uv.fs_scandir_next(handle)
			if not name then
				break
			end
			if name ~= ".git" and name ~= "node_modules" and name ~= ".direnv" and name ~= "target" then
				local path = directory .. "/" .. name
				if kind == "directory" then
					visit(path, depth + 1)
				elseif kind == "file" then
					files[#files + 1] = path
				end
			end
		end
	end
	visit(root, 0)
	table.sort(files)
	return files
end

local function fuzzy_score(text, query)
	local candidate, needle = text:lower(), query:lower()
	if needle == "" then
		return 0
	end
	local cursor, score, consecutive, previous = 1, 0, 0, 0
	for index = 1, #needle do
		local found = candidate:find(needle:sub(index, index), cursor, true)
		if not found then
			return nil
		end
		local boundary = found == 1 or candidate:sub(found - 1, found - 1):match("[/_.%-]") ~= nil
		consecutive = found == previous + 1 and consecutive + 1 or 0
		score = score + (boundary and 12 or 0) + consecutive * 5 - (found - cursor) - found * 0.002
		previous, cursor = found, found + 1
	end
	return score
end

local function choose(title, items, on_select)
	vim.ui.input({ prompt = title .. " query: " }, function(query)
		if query == nil then
			return
		end
		local ranked = {}
		for _, item in ipairs(items) do
			local score = fuzzy_score(item.label, query)
			if score then
				ranked[#ranked + 1] = { item = item, score = score }
			end
		end
		table.sort(ranked, function(left, right)
			if left.score == right.score then
				return left.item.label < right.item.label
			end
			return left.score > right.score
		end)
		local matches = {}
		for index = 1, math.min(#ranked, 100) do
			matches[index] = ranked[index].item
		end
		if #matches == 0 then
			vim.notify("No " .. title:lower() .. " match", vim.log.levels.INFO, { title = "NazoVim Picker" })
			return
		end
		vim.ui.select(matches, {
			prompt = title,
			format_item = function(item)
				return item.label
			end,
		}, on_select)
	end)
end

function M.files()
	local root = root_directory()
	local items = {}
	for _, path in ipairs(collect_files(root)) do
		items[#items + 1] = { label = vim.fs.relpath(root, path) or path, path = path }
	end
	choose("Files", items, function(item)
		if item and vim.fn.filereadable(item.path) == 1 then
			vim.cmd.edit({ args = { item.path } })
		end
	end)
end

function M.buffers()
	local items = {}
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == "" then
			local name = vim.api.nvim_buf_get_name(buf)
			if name ~= "" then
				items[#items + 1] = { label = name, buffer = buf }
			end
		end
	end
	choose("Buffers", items, function(item)
		if item and vim.api.nvim_buf_is_valid(item.buffer) then
			vim.api.nvim_set_current_buf(item.buffer)
		end
	end)
end

function M.recent()
	local items = {}
	for _, path in ipairs(vim.v.oldfiles) do
		if vim.fn.filereadable(path) == 1 then
			items[#items + 1] = { label = path, path = path }
		end
	end
	choose("Recent files", items, function(item)
		if item then
			vim.cmd.edit({ args = { item.path } })
		end
	end)
end

function M.grep()
	local root = root_directory()
	vim.ui.input({ prompt = "Search in " .. root .. ": " }, function(query)
		if not query or query == "" then
			return
		end
		if vim.fn.executable("rg") ~= 1 then
			vim.notify(
				"ripgrep (rg) is required for project search",
				vim.log.levels.ERROR,
				{ title = "NazoVim Picker" }
			)
			return
		end
		vim.system({
			"rg",
			"--line-number",
			"--column",
			"--no-heading",
			"--color",
			"never",
			"--smart-case",
			"--hidden",
			"--glob",
			"!.git/**",
			"--glob",
			"!**/node_modules/**",
			"--glob",
			"!**/target/**",
			"--",
			query,
		}, { cwd = root, text = true }, function(result)
			vim.schedule(function()
				local items = {}
				for _, line in ipairs(vim.split(result.stdout or "", "\n", { trimempty = true })) do
					local path, row, col, text = line:match("^(.-):(%d+):(%d+):(.*)$")
					if path then
						items[#items + 1] = {
							label = path .. ":" .. row .. ": " .. vim.trim(text),
							path = root .. "/" .. path,
							row = tonumber(row),
							col = tonumber(col),
						}
					end
					if #items >= 1000 then
						break
					end
				end
				if #items == 0 then
					local message = result.code == 1 and "No matches" or (result.stderr or "Search failed")
					vim.notify(message, result.code == 1 and vim.log.levels.INFO or vim.log.levels.ERROR, {
						title = "NazoVim Picker",
					})
					return
				end
				vim.ui.select(items, {
					prompt = "Search results",
					format_item = function(item)
						return item.label
					end,
				}, function(item)
					if item then
						vim.cmd.edit({ args = { item.path } })
						vim.api.nvim_win_set_cursor(0, { item.row, math.max(0, item.col - 1) })
					end
				end)
			end)
		end)
	end)
end

function M.setup()
	vim.api.nvim_create_user_command("NazoPickFiles", M.files, { desc = "Find a project file" })
	vim.api.nvim_create_user_command("NazoPickBuffers", M.buffers, { desc = "Choose an open buffer" })
	vim.api.nvim_create_user_command("NazoPickRecent", M.recent, { desc = "Choose a recent file" })
	vim.api.nvim_create_user_command("NazoPickGrep", M.grep, { desc = "Search project text" })
end

return M
