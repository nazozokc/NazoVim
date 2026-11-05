local M = {}

local namespace = vim.api.nvim_create_namespace("NazoVimPackageInfo")
local cache, generations, shown = {}, {}, {}
local requests, request_queue, active_requests = {}, {}, 0
local cache_ttl = 300
local max_requests = 4
local dependency_sections = { "dependencies", "devDependencies", "optionalDependencies", "peerDependencies" }

local function package_buffer(buf)
	local name = vim.api.nvim_buf_get_name(buf)
	return vim.fs.basename(name) == "package.json"
end

local function package_root(buf)
	local path = vim.fs.dirname(vim.api.nvim_buf_get_name(buf))
	local start = path
	while path do
		local markers = {
			{ "pnpm-lock.yaml", "pnpm" },
			{ "yarn.lock", "yarn" },
			{ "bun.lock", "bun" },
			{ "bun.lockb", "bun" },
			{ "package-lock.json", "npm" },
		}
		for _, marker in ipairs(markers) do
			if vim.fn.filereadable(path .. "/" .. marker[1]) == 1 then
				return path, marker[2]
			end
		end
		local parent = vim.fs.dirname(path)
		if parent == path then
			break
		end
		path = parent
	end
	return start, "npm"
end

local function read_dependencies(buf)
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local ok, manifest = pcall(vim.json.decode, table.concat(lines, "\n"))
	if not ok or type(manifest) ~= "table" then
		return nil, "package.json is not valid JSON"
	end
	local dependencies = {}
	local sections = {}
	for _, key in ipairs(dependency_sections) do
		if type(manifest[key]) == "table" then
			sections[key] = manifest[key]
		end
	end
	local active
	for row, line in ipairs(lines) do
		local section = line:match('^%s*"([%w]+)"%s*:%s*{%s*$')
		if section and sections[section] then
			active = section
		elseif active then
			local name = line:match('^%s*"([^"]+)"%s*:')
			if name and sections[active][name] then
				dependencies[#dependencies + 1] = {
					name = name,
					spec = sections[active][name],
					row = row - 1,
					section = active,
				}
			elseif line:match("^%s*}%s*,?%s*$") then
				active = nil
			end
		end
	end
	return dependencies
end

local function parse_version(value)
	local text = tostring(value or ""):match("[%d]+%.[%d]+%.[%d]+[%w%.%-+]*")
	if not text then
		return nil
	end
	local major, minor, patch, suffix = text:match("^(%d+)%.(%d+)%.(%d+)(.*)$")
	return { tonumber(major), tonumber(minor), tonumber(patch), suffix or "" }
end

local function compare_versions(left, right)
	for i = 1, 3 do
		if left[i] ~= right[i] then
			return left[i] < right[i] and -1 or 1
		end
	end
	if left[4] == right[4] then
		return 0
	elseif left[4] == "" then
		return 1
	elseif right[4] == "" then
		return -1
	end
	return left[4] < right[4] and -1 or 1
end

local function latest_satisfies(spec, latest)
	local version = parse_version(latest)
	local raw = vim.trim(tostring(spec or ""))
	if not version then
		return nil
	end
	if raw == "*" or raw == "latest" then
		return true
	end
	local operator, base_text = raw:match("^([%^~<>~=]*)%s*(.+)$")
	local base = parse_version(base_text or raw)
	if not base then
		return nil
	end
	local comparison = compare_versions(version, base)
	if operator == "^" then
		if comparison < 0 then
			return false
		end
		if base[1] > 0 then
			return version[1] == base[1]
		elseif base[2] > 0 then
			return version[1] == 0 and version[2] == base[2]
		end
		return version[1] == 0 and version[2] == 0 and version[3] == base[3]
	elseif operator == "~" then
		return comparison >= 0 and version[1] == base[1] and version[2] == base[2]
	elseif operator == ">=" then
		return comparison >= 0
	elseif operator == ">" then
		return comparison > 0
	elseif operator == "<=" then
		return comparison <= 0
	elseif operator == "<" then
		return comparison < 0
	elseif operator == "=" or operator == "" then
		return comparison == 0
	end
	return nil
end

local function set_version_mark(buf, dependency, latest)
	if not vim.api.nvim_buf_is_valid(buf) or not shown[buf] then
		return
	end
	local satisfies = latest_satisfies(dependency.spec, latest)
	if satisfies == true and vim.g.nazovim_package_info_hide_up_to_date ~= false then
		return
	end
	local text = " │ " .. latest
	local highlight = satisfies == false and "DiagnosticWarn" or "Comment"
	vim.api.nvim_buf_set_extmark(buf, namespace, dependency.row, 0, {
		virt_text = { { text, highlight } },
		virt_text_pos = "eol",
		priority = 90,
	})
end

local function pump_requests()
	while active_requests < max_requests and #request_queue > 0 do
		local request = table.remove(request_queue, 1)
		active_requests = active_requests + 1
		local ok, process = pcall(
			vim.system,
			{ "npm", "view", request.name, "version" },
			{ text = true },
			function(result)
				local version = result.code == 0 and vim.trim(result.stdout or "") or nil
				if version == "" then
					version = nil
				end
				vim.schedule(function()
					active_requests = math.max(0, active_requests - 1)
					requests[request.name] = nil
					if version then
						cache[request.name] = { version = version, time = os.time() }
					end
					for _, callback in ipairs(request.callbacks) do
						if version then
							callback(version)
						end
					end
					pump_requests()
				end)
			end
		)
		if not ok then
			active_requests = math.max(0, active_requests - 1)
			requests[request.name] = nil
			vim.schedule(function()
				vim.notify("Unable to start npm: " .. tostring(process), vim.log.levels.ERROR, {
					title = "NazoVim Package Info",
				})
				pump_requests()
			end)
		end
	end
end

local function latest_version(name, callback)
	local cached = cache[name]
	if cached and os.time() - cached.time < cache_ttl then
		callback(cached.version)
		return
	end
	if requests[name] then
		requests[name].callbacks[#requests[name].callbacks + 1] = callback
		return
	end
	requests[name] = { callbacks = { callback } }
	request_queue[#request_queue + 1] = { name = name, callbacks = requests[name].callbacks }
	pump_requests()
end

---Refresh latest-version annotations for the current package manifest.
function M.refresh(buf)
	buf = buf or vim.api.nvim_get_current_buf()
	if not package_buffer(buf) then
		return
	end
	vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
	local generation = (generations[buf] or 0) + 1
	generations[buf] = generation
	if not shown[buf] then
		return
	end
	local dependencies, err = read_dependencies(buf)
	if not dependencies then
		vim.notify(err, vim.log.levels.WARN, { title = "NazoVim Package Info" })
		return
	end
	if #dependencies > 0 and vim.fn.executable("npm") ~= 1 then
		vim.notify("npm is required to query registry versions", vim.log.levels.ERROR, {
			title = "NazoVim Package Info",
		})
		return
	end
	for _, dependency in ipairs(dependencies) do
		latest_version(dependency.name, function(version)
			if generations[buf] == generation then
				set_version_mark(buf, dependency, version)
			end
		end)
	end
end

---Show latest dependency versions for the current package.json.
function M.show()
	local buf = vim.api.nvim_get_current_buf()
	if not package_buffer(buf) then
		vim.notify("Open a package.json first", vim.log.levels.INFO, { title = "NazoVim Package Info" })
		return
	end
	shown[buf] = true
	M.refresh(buf)
end

---Hide latest-version annotations in the current package.json.
function M.hide()
	local buf = vim.api.nvim_get_current_buf()
	shown[buf] = false
	vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
end

---Toggle dependency version annotations in the current package.json.
function M.toggle()
	local buf = vim.api.nvim_get_current_buf()
	if shown[buf] then
		M.hide()
	else
		M.show()
	end
end

local function current_dependency(buf)
	local row = vim.api.nvim_win_get_cursor(0)[1] - 1
	for _, dependency in ipairs(read_dependencies(buf) or {}) do
		if dependency.row == row then
			return dependency
		end
	end
	return nil
end

local function package_manager(buf)
	local root, manager = package_root(buf)
	local commands = {
		npm = { add = "install", remove = "uninstall", update = "update" },
		pnpm = { add = "add", remove = "remove", update = "update" },
		yarn = { add = "add", remove = "remove", update = "up" },
		bun = { add = "add", remove = "remove", update = "update" },
	}
	return root, manager, commands[manager]
end

local function run_package_command(buf, operation, package_spec)
	local root, manager, commands = package_manager(buf)
	local executable = vim.g.nazovim_package_manager or manager
	if vim.fn.executable(executable) ~= 1 then
		vim.notify("Package manager not found: " .. executable, vim.log.levels.ERROR, {
			title = "NazoVim Package Info",
		})
		return
	end
	local argv = { executable, commands[operation], package_spec }
	vim.system(argv, { cwd = root, text = true }, function(result)
		vim.schedule(function()
			if result.code == 0 then
				vim.notify(
					table.concat(argv, " ") .. " completed",
					vim.log.levels.INFO,
					{ title = "NazoVim Package Info" }
				)
				if vim.api.nvim_buf_is_valid(buf) then
					vim.api.nvim_buf_call(buf, function()
						vim.cmd.checktime()
					end)
					M.refresh(buf)
				end
			else
				local detail = vim.trim(result.stderr or "")
				vim.notify(detail ~= "" and detail or "Package manager command failed", vim.log.levels.ERROR, {
					title = "NazoVim Package Info",
				})
			end
		end)
	end)
end

local function ask_package_name(callback)
	vim.ui.input({ prompt = "Package name: " }, function(name)
		if name and name:match("^[@%w][@%w%._/%-]*$") then
			callback(name)
		elseif name then
			vim.notify("Invalid package name", vim.log.levels.ERROR, { title = "NazoVim Package Info" })
		end
	end)
end

---Add a package to the current project manifest.
function M.install()
	local buf = vim.api.nvim_get_current_buf()
	if not package_buffer(buf) then
		vim.notify("Open a package.json first", vim.log.levels.INFO, { title = "NazoVim Package Info" })
		return
	end
	ask_package_name(function(name)
		run_package_command(buf, "add", name)
	end)
end

---Update the dependency under the cursor.
function M.update()
	local buf = vim.api.nvim_get_current_buf()
	local dependency = current_dependency(buf)
	if dependency then
		run_package_command(buf, "update", dependency.name)
	else
		vim.notify("Place the cursor on a dependency entry", vim.log.levels.INFO, { title = "NazoVim Package Info" })
	end
end

---Remove the dependency under the cursor after confirmation.
function M.remove()
	local buf = vim.api.nvim_get_current_buf()
	local dependency = current_dependency(buf)
	if not dependency then
		vim.notify("Place the cursor on a dependency entry", vim.log.levels.INFO, { title = "NazoVim Package Info" })
		return
	end
	vim.ui.select({ "Remove " .. dependency.name, "Cancel" }, { prompt = "Remove dependency?" }, function(_, index)
		if index == 1 then
			run_package_command(buf, "remove", dependency.name)
		end
	end)
end

---Change the version requirement of the dependency under the cursor.
function M.change_version()
	local buf = vim.api.nvim_get_current_buf()
	local dependency = current_dependency(buf)
	if not dependency then
		vim.notify("Place the cursor on a dependency entry", vim.log.levels.INFO, { title = "NazoVim Package Info" })
		return
	end
	vim.ui.input({ prompt = dependency.name .. " version: ", default = dependency.spec }, function(version)
		if version and vim.trim(version) ~= "" then
			run_package_command(buf, "add", dependency.name .. "@" .. vim.trim(version))
		end
	end)
end

---Register package info commands, keymaps, and package.json auto-show behavior.
function M.setup()
	local group = vim.api.nvim_create_augroup("NazoVimPackageInfo", { clear = true })
	vim.api.nvim_create_autocmd({ "BufEnter", "TextChanged", "TextChangedI" }, {
		group = group,
		callback = function(event)
			if package_buffer(event.buf) then
				if vim.g.nazovim_package_info_autostart ~= false then
					shown[event.buf] = true
				end
				M.refresh(event.buf)
			end
		end,
	})
	vim.api.nvim_create_autocmd("BufWipeout", {
		group = group,
		callback = function(event)
			shown[event.buf], generations[event.buf] = nil, nil
		end,
	})
	vim.api.nvim_create_user_command("NazoPackageInfoShow", M.show, { desc = "Show package versions" })
	vim.api.nvim_create_user_command("NazoPackageInfoHide", M.hide, { desc = "Hide package versions" })
	vim.api.nvim_create_user_command("NazoPackageInstall", M.install, { desc = "Add a package" })
	vim.api.nvim_create_user_command("NazoPackageUpdate", M.update, { desc = "Update dependency under cursor" })
	vim.api.nvim_create_user_command("NazoPackageRemove", M.remove, { desc = "Remove dependency under cursor" })
	vim.api.nvim_create_user_command("NazoPackageVersion", M.change_version, { desc = "Change dependency version" })
	vim.keymap.set("n", "<leader>ns", M.show, { desc = "Show package versions", silent = true })
	vim.keymap.set("n", "<leader>nc", M.hide, { desc = "Hide package versions", silent = true })
	vim.keymap.set("n", "<leader>nt", M.toggle, { desc = "Toggle package versions", silent = true })
	vim.keymap.set("n", "<leader>nu", M.update, { desc = "Update package", silent = true })
	vim.keymap.set("n", "<leader>nd", M.remove, { desc = "Delete package", silent = true })
	vim.keymap.set("n", "<leader>ni", M.install, { desc = "Install new package", silent = true })
	vim.keymap.set("n", "<leader>np", M.change_version, { desc = "Change package version", silent = true })
end

return M
