local M = {}
local response_id = 0

local function lines_to_requests(buf)
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local variables, requests = {}, {}
	local current, start_line = {}, 1
	local function finish(end_line)
		if #current > 0 then
			requests[#requests + 1] = {
				lines = current,
				variables = vim.deepcopy(variables),
				start_line = start_line,
				end_line = end_line,
			}
		end
		current = {}
	end
	for index, line in ipairs(lines) do
		if line:match("^%s*###") then
			finish(index - 1)
			start_line = index
		else
			local name, value = line:match("^%s*@([%w_.-]+)%s*=%s*(.-)%s*$")
			if name then
				variables[name] = value
			end
			current[#current + 1] = line
		end
	end
	finish(#lines)

	return requests
end

local function interpolate(value, variables)
	return (value:gsub("{{%s*([%w_.-]+)%s*}}", function(name)
		return variables[name] or vim.env[name] or ""
	end))
end

local function parse_request(request, variables)
	local method, url, headers, body = nil, nil, {}, {}
	local in_body = false
	for _, raw in ipairs(request.lines) do
		local variable = raw:match("^%s*@[%w_.-]+%s*=") ~= nil
		if not method and not variable and not raw:match("^%s*#") and raw:match("%S") then
			method, url = raw:match("^%s*([%a]+)%s+(%S+)")
		elseif method and not in_body then
			if raw:match("^%s*@[%w_.-]+%s*=") then
				-- Variables can be declared above a request in the block.
			elseif raw:match("^%s*$") then
				in_body = true
			elseif not raw:match("^%s*#") then
				local name, value = raw:match("^%s*([^:]+):%s*(.-)%s*$")
				if name then
					headers[#headers + 1] = interpolate(name .. ": " .. value, variables)
				end
			end
		elseif in_body then
			body[#body + 1] = interpolate(raw, variables)
		end
	end
	if not method or not url then
		return nil, "request must start with METHOD and URL"
	end
	url = interpolate(url, variables)
	return { method = method:upper(), url = url, headers = headers, body = table.concat(body, "\n") }
end

local function show_response(title, result)
	response_id = response_id + 1
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(buf, "NazoHTTP://" .. title:gsub("[^%w_.-]", "_") .. "/" .. response_id)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(result, "\n", { plain = true }))
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].filetype = "http"
	vim.cmd("botright split")
	vim.api.nvim_win_set_buf(0, buf)
	vim.cmd("normal! gg")
end

local function send_one(request, variables, label, done)
	done = done
		or function(ok, message)
			if not ok then
				vim.notify(message, vim.log.levels.ERROR, { title = "NazoVim HTTP" })
			end
		end
	local parsed, err = parse_request(request, variables)
	if not parsed then
		done(false, label .. ": " .. err)
		return
	end
	if vim.fn.executable("curl") ~= 1 then
		done(false, "curl is required to send HTTP requests")
		return
	end

	local command = {
		"curl",
		"--include",
		"--silent",
		"--show-error",
		"--max-time",
		"120",
		"--request",
		parsed.method,
		"--url",
		parsed.url,
	}
	for _, header in ipairs(parsed.headers) do
		command[#command + 1] = "--header"
		command[#command + 1] = header
	end
	if parsed.body ~= "" then
		command[#command + 1] = "--data-binary"
		command[#command + 1] = "@-"
	end
	vim.system(command, { stdin = parsed.body, text = true }, function(result)
		vim.schedule(function()
			local output = result.stdout or ""
			if result.stderr and result.stderr ~= "" then
				output = output .. (output == "" and "" or "\n") .. "[curl] " .. result.stderr
			end
			if result.code ~= 0 then
				done(false, label .. " failed (curl exit " .. result.code .. "): " .. output)
				return
			end
			show_response(label .. " " .. parsed.method, output ~= "" and output or "(empty response)")
			done(true)
		end)
	end)
end

function M.send_current()
	local requests = lines_to_requests(0)
	local cursor = vim.api.nvim_win_get_cursor(0)[1]
	for _, request in ipairs(requests) do
		if cursor >= request.start_line and cursor <= request.end_line then
			send_one(
				request,
				request.variables,
				vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t") .. ":" .. request.start_line
			)
			return
		end
	end
	vim.notify("No HTTP request found at the cursor", vim.log.levels.WARN, { title = "NazoVim HTTP" })
end

function M.send_all()
	local requests = lines_to_requests(0)
	if #requests == 0 then
		vim.notify("No HTTP requests found in this buffer", vim.log.levels.WARN, { title = "NazoVim HTTP" })
		return
	end
	local file = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t")
	local function send_index(index)
		if index > #requests then
			vim.notify("Sent " .. #requests .. " HTTP requests", vim.log.levels.INFO, { title = "NazoVim HTTP" })
			return
		end
		send_one(
			requests[index],
			requests[index].variables,
			file .. ":" .. requests[index].start_line,
			function(ok, message)
				if not ok then
					vim.notify(message, vim.log.levels.ERROR, { title = "NazoVim HTTP" })
					return
				end
				send_index(index + 1)
			end
		)
	end
	send_index(1)
end

function M.scratch()
	vim.cmd("botright new")
	vim.bo.filetype = "http"
	vim.bo.bufhidden = "wipe"
	vim.api.nvim_buf_set_lines(0, 0, -1, false, { "### Example request", "GET https://example.com", "" })
	vim.cmd("normal! gg$")
end

function M.setup()
	vim.keymap.set("n", "<leader>Rs", M.send_current, { desc = "Send HTTP request" })
	vim.keymap.set("n", "<leader>Ra", M.send_all, { desc = "Send all HTTP requests" })
	vim.keymap.set("n", "<leader>Rb", M.scratch, { desc = "Open HTTP scratchpad" })
	vim.api.nvim_create_user_command("NazoHttpSend", M.send_current, { desc = "Send HTTP request under cursor" })
	vim.api.nvim_create_user_command("NazoHttpSendAll", M.send_all, { desc = "Send all HTTP requests in buffer" })
	vim.api.nvim_create_user_command("NazoHttpScratch", M.scratch, { desc = "Open an HTTP scratchpad" })
end

return M
