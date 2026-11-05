local M = {}

local namespace = vim.api.nvim_create_namespace("NazoVimCoverage")
local records = {}
local report_path
local report_mtime
local enabled = false
local summary_win
local summary_buf
local summary_files = {}

local defaults = {
	covered = { fg = "#C3E88D" },
	uncovered = { fg = "#F07178" },
}

local function project_root(buf)
	return vim.fs.root(buf or 0, { ".git", "pnpm-workspace.yaml", "package.json", "Cargo.toml", "pyproject.toml" })
		or vim.fn.getcwd()
end

local function resolve_source(path, root)
	if path:match("^/") then
		return vim.fs.normalize(path)
	end
	return vim.fs.normalize(root .. "/" .. path)
end

local function parse_lcov(path, root)
	local ok, lines = pcall(vim.fn.readfile, path)
	if not ok then
		return nil, "Could not read coverage report: " .. tostring(lines)
	end
	local result, current = {}, nil
	local function finish()
		if current and current.path then
			local aggregate = result[current.path]
			if aggregate then
				for line, hits in pairs(current.lines) do
					aggregate.lines[line] = (aggregate.lines[line] or 0) + hits
				end
			else
				aggregate = current
				result[current.path] = aggregate
			end
			local executable, covered = 0, 0
			for _, hits in pairs(aggregate.lines) do
				executable = executable + 1
				if hits > 0 then
					covered = covered + 1
				end
			end
			aggregate.executable = executable
			aggregate.covered = covered
		end
		current = nil
	end
	for _, line in ipairs(lines) do
		local source = line:match("^SF:(.*)$")
		if source then
			finish()
			current = { path = resolve_source(source, root), lines = {} }
		elseif current then
			local number, hits = line:match("^DA:(%d+),([%-]?%d+)")
			if number and tonumber(hits) and tonumber(hits) >= 0 then
				current.lines[tonumber(number)] = tonumber(hits)
			end
			if line == "end_of_record" then
				finish()
			end
		end
	end
	finish()
	return result
end

local function highlight_groups()
	for name, value in pairs(defaults) do
		vim.api.nvim_set_hl(0, "NazoCoverage" .. name:sub(1, 1):upper() .. name:sub(2), value)
	end
end

local function clear_buffer(buf)
	if vim.api.nvim_buf_is_valid(buf) then
		vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
	end
end

local function render_buffer(buf)
	clear_buffer(buf)
	if not enabled or not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_buf_is_loaded(buf) then
		return
	end
	local path = vim.api.nvim_buf_get_name(buf)
	local file = records[vim.fs.normalize(path)]
	if not file then
		return
	end
	for line, hits in pairs(file.lines) do
		if line <= vim.api.nvim_buf_line_count(buf) then
			local covered = hits > 0
			vim.api.nvim_buf_set_extmark(buf, namespace, line - 1, 0, {
				sign_text = "▎",
				sign_hl_group = covered and "NazoCoverageCovered" or "NazoCoverageUncovered",
				priority = 100,
			})
		end
	end
end

local function render_all()
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		render_buffer(buf)
	end
end

local function find_report()
	local root = project_root(0)
	for _, relative in ipairs({ "coverage/lcov.info", "lcov.info", "coverage.info", "coverage/lcov-report.info" }) do
		local path = root .. "/" .. relative
		if vim.fn.filereadable(path) == 1 then
			return path, root
		end
	end
	return nil, root
end

local function modified_signature(stat)
	if not stat then
		return nil
	end
	local mtime = stat.mtime or {}
	return tostring(mtime.sec or 0) .. ":" .. tostring(mtime.nsec or 0) .. ":" .. tostring(stat.size or 0)
end

---Load an LCOV report, resolving source paths against the active project root.
---@param path? string
function M.load(path)
	local root = project_root(0)
	if not path or path == "" then
		path, root = find_report()
	end
	if not path then
		vim.notify(
			"No LCOV report found. Use :CoverageLoad <path>.",
			vim.log.levels.WARN,
			{ title = "NazoVim Coverage" }
		)
		return false
	end
	path = vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
	local loaded, err = parse_lcov(path, root)
	if not loaded then
		vim.notify(err, vim.log.levels.ERROR, { title = "NazoVim Coverage" })
		return false
	end
	records = loaded
	report_path = path
	local stat = vim.uv.fs_stat(path)
	report_mtime = modified_signature(stat)
	enabled = true
	render_all()
	vim.notify(string.format("Loaded coverage for %d files", vim.tbl_count(records)), vim.log.levels.INFO, {
		title = "NazoVim Coverage",
	})
	return true
end

local function maybe_reload()
	if not report_path then
		return
	end
	local stat = vim.uv.fs_stat(report_path)
	local mtime = modified_signature(stat)
	if mtime and mtime ~= report_mtime then
		M.load(report_path)
	end
end

local function ordered_summary()
	local files, total_executable, total_covered = {}, 0, 0
	for path, file in pairs(records) do
		local ratio = file.executable > 0 and (file.covered / file.executable * 100) or 100
		files[#files + 1] = { path = path, executable = file.executable, covered = file.covered, ratio = ratio }
		total_executable = total_executable + file.executable
		total_covered = total_covered + file.covered
	end
	table.sort(files, function(a, b)
		return a.path < b.path
	end)
	local total_ratio = total_executable > 0 and (total_covered / total_executable * 100) or 100
	return files, total_executable, total_covered, total_ratio
end

local function close_summary()
	if summary_win and vim.api.nvim_win_is_valid(summary_win) then
		vim.api.nvim_win_close(summary_win, true)
	end
	summary_win, summary_buf = nil, nil
end

---Display per-file and total line coverage in a navigable floating window.
function M.summary()
	if vim.tbl_isempty(records) then
		if not M.load() then
			return
		end
	end
	local total_executable, total_covered, total_ratio
	summary_files, total_executable, total_covered, total_ratio = ordered_summary()
	local lines = {
		string.format("Coverage  %.1f%%   %d/%d lines", total_ratio, total_covered, total_executable),
		"",
		"Press <CR> to open a file, q to close",
		"",
	}
	local width = math.min(math.max(56, math.floor(vim.o.columns * 0.75)), math.max(1, vim.o.columns - 4))
	for _, file in ipairs(summary_files) do
		local path = vim.fn.fnamemodify(file.path, ":~:.")
		local available = math.max(12, width - 27)
		if vim.fn.strdisplaywidth(path) > available then
			local count = vim.fn.strchars(path)
			path = "…" .. vim.fn.strcharpart(path, math.max(0, count - available + 1))
		end
		lines[#lines + 1] =
			string.format("%-" .. available .. "s %5.1f%% %5d/%-5d", path, file.ratio, file.covered, file.executable)
	end
	close_summary()
	summary_buf = vim.api.nvim_create_buf(false, true)
	vim.bo[summary_buf].buftype = "nofile"
	vim.bo[summary_buf].bufhidden = "wipe"
	vim.bo[summary_buf].swapfile = false
	vim.api.nvim_buf_set_lines(summary_buf, 0, -1, false, lines)
	vim.bo[summary_buf].modifiable = false
	local height = math.min(#lines, math.max(1, vim.o.lines - vim.o.cmdheight - 4))
	summary_win = vim.api.nvim_open_win(summary_buf, true, {
		relative = "editor",
		row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
		col = math.max(0, math.floor((vim.o.columns - width) / 2)),
		width = width,
		height = height,
		style = "minimal",
		border = "rounded",
		title = " Coverage Summary ",
		title_pos = "center",
	})
	vim.wo[summary_win].cursorline = true
	vim.wo[summary_win].wrap = false
	vim.wo[summary_win].number = false
	vim.wo[summary_win].relativenumber = false
	vim.wo[summary_win].signcolumn = "no"
	vim.keymap.set("n", "q", close_summary, { buffer = summary_buf, nowait = true, desc = "Close coverage summary" })
	vim.keymap.set("n", "<Esc>", close_summary, { buffer = summary_buf, nowait = true })
	vim.keymap.set("n", "<CR>", function()
		local row = vim.api.nvim_win_get_cursor(0)[1] - 4
		local file = summary_files[row]
		close_summary()
		if file then
			vim.cmd.edit({ args = { file.path } })
		end
	end, { buffer = summary_buf, nowait = true, desc = "Open covered file" })
	for index = 1, #summary_files do
		local row = index + 3
		local minimum = tonumber(vim.g.nazovim_coverage_minimum) or 80
		local group = summary_files[index].ratio < minimum and "DiagnosticWarn" or "DiagnosticOk"
		vim.api.nvim_buf_add_highlight(summary_buf, namespace, group, row, 0, -1)
	end
end

---Clear all coverage signs while retaining the loaded report.
function M.hide()
	enabled = false
	render_all()
end

---Toggle coverage signs for loaded source files.
function M.toggle()
	enabled = not enabled
	render_all()
	vim.notify(
		"Coverage signs " .. (enabled and "shown" or "hidden"),
		vim.log.levels.INFO,
		{ title = "NazoVim Coverage" }
	)
end

---Install coverage commands and reload hooks.
function M.setup()
	highlight_groups()
	local group = vim.api.nvim_create_augroup("NazoVimCoverage", { clear = true })
	vim.api.nvim_create_autocmd({ "BufEnter", "FocusGained", "FileChangedShellPost" }, {
		group = group,
		callback = function(event)
			maybe_reload()
			render_buffer(event.buf)
		end,
	})
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = group,
		callback = highlight_groups,
	})
	vim.api.nvim_create_user_command("CoverageLoad", function(args)
		M.load(args.args)
	end, { nargs = "?", complete = "file", desc = "Load an LCOV coverage report" })
	vim.api.nvim_create_user_command("CoverageSummary", M.summary, { desc = "Show coverage summary" })
	vim.api.nvim_create_user_command("CoverageToggle", M.toggle, { desc = "Toggle coverage signs" })
	vim.api.nvim_create_user_command("CoverageHide", M.hide, { desc = "Hide coverage signs" })
	vim.schedule(function()
		local path = find_report()
		if path then
			M.load(path)
		end
	end)
end

return M
