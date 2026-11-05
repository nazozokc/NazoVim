local M = {}

local active_process
local active_file

local function watcher_for(file)
	local directory = vim.fs.dirname(file)
	while directory and directory ~= "" do
		local local_watcher = vim.fs.joinpath(directory, "node_modules", ".bin", "swagger-ui-watcher")
		if vim.fn.executable(local_watcher) == 1 then
			return local_watcher
		end
		local parent = vim.fs.dirname(directory)
		if parent == directory then
			break
		end
		directory = parent
	end
	local global_watcher = vim.fn.exepath("swagger-ui-watcher")
	return global_watcher ~= "" and global_watcher or nil
end

local function current_file(argument)
	local file = argument ~= "" and vim.fn.expand(argument) or vim.api.nvim_buf_get_name(0)
	if file == "" then
		return nil
	end
	return vim.fn.fnamemodify(file, ":p")
end

---Stop the active OpenAPI preview process.
function M.stop(quiet)
	local process = active_process
	active_process, active_file = nil, nil
	if process then
		pcall(process.kill, process, 15)
		if not quiet then
			vim.notify("OpenAPI preview stopped", vim.log.levels.INFO, { title = "NazoVim" })
		end
		return true
	end
	if not quiet then
		vim.notify("No OpenAPI preview is running", vim.log.levels.INFO, { title = "NazoVim" })
	end
	return false
end

---Start swagger-ui-watcher for the current buffer or a supplied file.
function M.start(argument)
	local file = current_file(argument or "")
	if not file then
		vim.notify("Open an OpenAPI/Swagger file first", vim.log.levels.WARN, { title = "NazoVim" })
		return false
	end
	local watcher = watcher_for(file)
	if not watcher then
		vim.notify("swagger-ui-watcher is required (install it with npm)", vim.log.levels.ERROR, { title = "NazoVim" })
		return false
	end
	if active_process and active_file == file then
		vim.notify("Preview is already running for this file", vim.log.levels.INFO, { title = "NazoVim" })
		return true
	end
	M.stop(true)
	local port = tonumber(vim.g.nazovim_swagger_preview_port) or 8000
	if port < 1 or port > 65535 or port % 1 ~= 0 then
		vim.notify("Invalid g:nazovim_swagger_preview_port", vim.log.levels.ERROR, { title = "NazoVim" })
		return false
	end
	local host = tostring(vim.g.nazovim_swagger_preview_host or "localhost")
	local process
	local ok, result = pcall(vim.system, {
		watcher,
		"-p",
		tostring(port),
		"-h",
		host,
		file,
	}, { text = true }, function(exit_result)
		vim.schedule(function()
			if active_process ~= process then
				return
			end
			active_process, active_file = nil, nil
			if exit_result.code ~= 0 then
				local detail = vim.trim(exit_result.stderr or "")
				vim.notify(
					"swagger-ui-watcher exited with code "
						.. exit_result.code
						.. (detail ~= "" and (": " .. detail) or ""),
					vim.log.levels.ERROR,
					{ title = "NazoVim" }
				)
			end
		end)
	end)
	if not ok then
		vim.notify(
			"Could not start swagger-ui-watcher: " .. tostring(result),
			vim.log.levels.ERROR,
			{ title = "NazoVim" }
		)
		return false
	end
	process = result
	active_process, active_file = process, file
	vim.notify(
		string.format("OpenAPI preview started on %s:%d", host, port),
		vim.log.levels.INFO,
		{ title = "NazoVim" }
	)
	return true
end

---Toggle the preview for the current file.
function M.toggle(argument)
	local file = current_file(argument or "")
	if active_process and active_file == file then
		return M.stop()
	end
	return M.start(argument)
end

---Register standalone OpenAPI preview commands.
function M.setup()
	vim.api.nvim_create_user_command("NazoSwaggerPreview", function(command)
		M.start(command.args)
	end, { nargs = "?", complete = "file", desc = "Preview the current OpenAPI/Swagger file" })
	vim.api.nvim_create_user_command("NazoSwaggerPreviewStop", function()
		M.stop()
	end, { desc = "Stop the OpenAPI preview" })
	vim.api.nvim_create_user_command("NazoSwaggerPreviewToggle", function(command)
		M.toggle(command.args)
	end, { nargs = "?", complete = "file", desc = "Toggle the OpenAPI preview" })
	vim.api.nvim_create_user_command("SwaggerPreview", function(command)
		M.start(command.args)
	end, { nargs = "?", complete = "file", desc = "Preview the current OpenAPI/Swagger file" })
	vim.api.nvim_create_user_command("SwaggerPreviewStop", function()
		M.stop()
	end, { desc = "Stop the OpenAPI preview" })
	vim.api.nvim_create_user_command("SwaggerPreviewToggle", function(command)
		M.toggle(command.args)
	end, { nargs = "?", complete = "file", desc = "Toggle the OpenAPI preview" })
	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = vim.api.nvim_create_augroup("NazoSwaggerPreview", { clear = true }),
		callback = function()
			M.stop(true)
		end,
	})
end

return M
