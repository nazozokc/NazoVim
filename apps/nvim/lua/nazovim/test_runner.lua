local M = {}

local output_buffer
local output_window
local current_job
local run_generation = 0
local stream_fragments = {}

local function project_info(path)
	local directory = vim.fs.dirname(path)
	while directory and directory ~= "" do
		local package_path = vim.fs.joinpath(directory, "package.json")
		if vim.fn.filereadable(package_path) == 1 then
			local ok, package = pcall(vim.json.decode, table.concat(vim.fn.readfile(package_path), "\n"))
			if not ok or type(package) ~= "table" then
				package = {}
			end
			return directory, package
		end
		local parent = vim.fs.dirname(directory)
		if parent == directory then
			break
		end
		directory = parent
	end
	return vim.fs.dirname(path), {}
end

local function has_file(root, pattern)
	return #vim.fn.globpath(root, pattern, false, true) > 0
end

local function package_manager(root, package)
	local declared = type(package.packageManager) == "string" and package.packageManager:match("^([^@]+)")
	if declared then
		return declared
	end
	for _, candidate in ipairs({
		{ name = "pnpm", lock = "pnpm-lock.yaml" },
		{ name = "yarn", lock = "yarn.lock" },
		{ name = "bun", lock = "bun.lock" },
		{ name = "bun", lock = "bun.lockb" },
	}) do
		if vim.fn.filereadable(vim.fs.joinpath(root, candidate.lock)) == 1 then
			return candidate.name
		end
	end
	return "npm"
end

local function choose_runner(root, package, file)
	local relative = vim.fs.relpath(root, file) or file
	local scripts = type(package.scripts) == "table" and package.scripts or {}
	local test_script = tostring(scripts.test or "")
	local dependencies = vim.tbl_extend(
		"force",
		type(package.dependencies) == "table" and package.dependencies or {},
		type(package.devDependencies) == "table" and package.devDependencies or {}
	)
	local candidates = {}
	local has_playwright_config = has_file(root, "playwright.config.*")
	if
		relative:match("[/\\]e2e[/\\]")
		or relative:match("[/\\]playwright[/\\]")
		or has_playwright_config and (relative:match("^tests[/\\]") or relative:match("%.spec%.[jt]sx?$"))
	then
		candidates[#candidates + 1] = "playwright"
	end
	if dependencies.vitest or test_script:find("vitest", 1, true) then
		candidates[#candidates + 1] = "vitest"
	end
	if dependencies.jest or test_script:find("jest", 1, true) then
		candidates[#candidates + 1] = "jest"
	end
	if dependencies["@playwright/test"] or has_playwright_config then
		candidates[#candidates + 1] = "playwright"
	end
	local seen = {}
	for _, runner in ipairs(candidates) do
		if not seen[runner] then
			seen[runner] = true
			local local_bin = vim.fs.joinpath(root, "node_modules", ".bin", runner)
			if vim.fn.executable(local_bin) == 1 then
				return { local_bin }, runner
			end
		end
	end
	local runner = candidates[1]
	if not runner then
		if test_script ~= "" then
			local manager = package_manager(root, package)
			local commands = {
				npm = { "npm", "test", "--" },
				pnpm = { "pnpm", "test", "--" },
				yarn = { "yarn", "test" },
				bun = { "bun", "run", "test", "--" },
			}
			return commands[manager] or commands.npm, "script"
		end
		return nil, nil
	end
	local manager = package_manager(root, package)
	if manager == "pnpm" then
		return { "pnpm", "exec", runner }, runner
	elseif manager == "yarn" then
		return { "yarn", runner }, runner
	elseif manager == "bun" then
		return { "bun", "x", "--no-install", runner }, runner
	end
	return { "npx", "--no-install", runner }, runner
end

local function open_output()
	if output_window and vim.api.nvim_win_is_valid(output_window) then
		vim.api.nvim_set_current_win(output_window)
		return
	end
	if not output_buffer or not vim.api.nvim_buf_is_valid(output_buffer) then
		output_buffer = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_name(output_buffer, "NazoTest://output")
		vim.bo[output_buffer].buftype = "nofile"
		vim.bo[output_buffer].bufhidden = "hide"
		vim.bo[output_buffer].swapfile = false
		vim.bo[output_buffer].filetype = "nazotest"
	end
	vim.cmd("botright 14split")
	output_window = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(output_window, output_buffer)
	vim.wo[output_window].number = false
	vim.wo[output_window].relativenumber = false
	vim.wo[output_window].signcolumn = "no"
	vim.wo[output_window].wrap = false
	vim.keymap.set("n", "q", M.toggle_output, { buffer = output_buffer, desc = "Close test output" })
	vim.keymap.set("n", "<Esc>", M.toggle_output, { buffer = output_buffer, desc = "Close test output" })
end

local function append_output(lines)
	if not output_buffer or not vim.api.nvim_buf_is_valid(output_buffer) then
		return
	end
	vim.bo[output_buffer].modifiable = true
	vim.api.nvim_buf_set_lines(output_buffer, -1, -1, false, lines)
	vim.bo[output_buffer].modifiable = false
	if output_window and vim.api.nvim_win_is_valid(output_window) then
		local count = vim.api.nvim_buf_line_count(output_buffer)
		vim.api.nvim_win_set_cursor(output_window, { count, 0 })
	end
end

local function output_callback(data, stream, request)
	if not data then
		return
	end
	local fragments = stream_fragments[request]
	if not fragments then
		return
	end
	local combined = (fragments[stream] or "") .. table.concat(data, "\n")
	local lines = vim.split(combined, "\n", { plain = true })
	if data[#data] ~= "" then
		fragments[stream] = table.remove(lines)
	else
		fragments[stream] = ""
	end
	if #lines > 0 then
		vim.schedule(function()
			if request == run_generation then
				append_output(lines)
			end
		end)
	end
end

local function test_name_at(buf, row)
	local lines = vim.api.nvim_buf_get_lines(buf, 0, row, false)
	for index = #lines, 1, -1 do
		local line = lines[index]
		local name = line:match("%f[%a]it%s*%(%s*['\"](.-)['\"]") or line:match("%f[%a]test%s*%(%s*['\"](.-)['\"]")
		if name and name ~= "" then
			return name
		end
	end
end

local function run(mode)
	local buf = vim.api.nvim_get_current_buf()
	local file = vim.api.nvim_buf_get_name(buf)
	if mode ~= "all" and (file == "" or vim.bo[buf].buftype ~= "") then
		vim.notify("Open a test file before running tests", vim.log.levels.WARN, { title = "NazoVim Test" })
		return
	end
	local root, package = project_info(file ~= "" and file or (vim.fn.getcwd() .. "/package.json"))
	local argv, runner = choose_runner(root, package, file ~= "" and file or root)
	if not argv then
		vim.notify("No Jest, Vitest, Playwright, or package test script was found", vim.log.levels.ERROR, {
			title = "NazoVim Test",
		})
		return
	end
	local relative = file ~= "" and (vim.fs.relpath(root, file) or file) or nil
	if mode == "file" then
		if runner == "playwright" then
			argv[#argv + 1] = "test"
		end
		argv[#argv + 1] = relative
	elseif mode == "nearest" then
		if runner == "playwright" then
			argv[#argv + 1] = "test"
		end
		argv[#argv + 1] = relative
		local test_name = test_name_at(buf, vim.api.nvim_win_get_cursor(0)[1])
		if test_name and (runner == "jest" or runner == "vitest") then
			argv[#argv + 1] = "-t"
			argv[#argv + 1] = test_name
		elseif test_name and runner == "playwright" then
			argv[#argv + 1] = "--grep"
			argv[#argv + 1] = test_name
		end
	end
	run_generation = run_generation + 1
	local request = run_generation
	if current_job and current_job > 0 then
		vim.fn.jobstop(current_job)
	end
	stream_fragments = {}
	stream_fragments[request] = { stdout = "", stderr = "" }
	if not output_buffer or not vim.api.nvim_buf_is_valid(output_buffer) then
		open_output()
	end
	vim.bo[output_buffer].modifiable = true
	vim.api.nvim_buf_set_lines(output_buffer, 0, -1, false, {
		"$ " .. table.concat(argv, " "),
		"",
	})
	vim.bo[output_buffer].modifiable = false
	open_output()
	local job = vim.fn.jobstart(argv, {
		cwd = root,
		stdout_buffered = false,
		stderr_buffered = false,
		on_stdout = function(_, data)
			output_callback(data, "stdout", request)
		end,
		on_stderr = function(_, data)
			output_callback(data, "stderr", request)
		end,
		on_exit = function(_, code)
			vim.schedule(function()
				if request ~= run_generation then
					return
				end
				current_job = nil
				local fragments = stream_fragments[request] or {}
				local pending = {}
				for _, stream in ipairs({ "stdout", "stderr" }) do
					if fragments[stream] and fragments[stream] ~= "" then
						pending[#pending + 1] = fragments[stream]
					end
				end
				stream_fragments[request] = nil
				if #pending > 0 then
					append_output(pending)
				end
				append_output({ "", "Process exited with code " .. code })
			end)
		end,
	})
	if job <= 0 then
		current_job = nil
		stream_fragments[request] = nil
		append_output({ "Could not start the test command" })
		return
	end
	current_job = job
end

---Run the nearest test, current test file, or all tests in the current project.
function M.run(mode)
	mode = mode or "nearest"
	if mode ~= "nearest" and mode ~= "file" and mode ~= "all" then
		vim.notify("Usage: :NazoTestRun [nearest|file|all]", vim.log.levels.ERROR, { title = "NazoVim Test" })
		return
	end
	run(mode)
end

---Toggle the most recent test output window.
function M.toggle_output()
	if output_window and vim.api.nvim_win_is_valid(output_window) then
		vim.api.nvim_win_close(output_window, true)
		output_window = nil
		return
	end
	if output_buffer and vim.api.nvim_buf_is_valid(output_buffer) then
		open_output()
	end
end

---Stop the currently running test process.
function M.stop()
	if current_job and current_job > 0 then
		run_generation = run_generation + 1
		stream_fragments = {}
		vim.fn.jobstop(current_job)
		current_job = nil
		append_output({ "", "Test process stopped" })
	end
end

---Install test runner mappings and commands.
function M.setup()
	vim.keymap.set("n", "<leader>tr", function()
		M.run("nearest")
	end, { desc = "Run nearest test" })
	vim.keymap.set("n", "<leader>tR", function()
		M.run("all")
	end, { desc = "Run all tests" })
	vim.keymap.set("n", "<leader>tf", function()
		M.run("file")
	end, { desc = "Run test file" })
	vim.keymap.set("n", "<leader>to", M.toggle_output, { desc = "Toggle test output" })
	vim.api.nvim_create_user_command("NazoTestRun", function(command)
		M.run(command.args ~= "" and command.args or "nearest")
	end, { nargs = "?", desc = "Run nearest, file, or all tests" })
	vim.api.nvim_create_user_command("NazoTestStop", M.stop, { desc = "Stop the test process" })
end

return M
