local M = {}

local title = "NazoVim LSP"

local function notify(message, level)
	vim.notify(message, level or vim.log.levels.INFO, { title = title })
end

---Names of the servers attached to a buffer, without duplicates.
---@param buffer? integer
---@return string[]
function M.names(buffer)
	local seen, names = {}, {}
	for _, client in ipairs(vim.lsp.get_clients({ bufnr = buffer or 0 })) do
		if not seen[client.name] then
			seen[client.name] = true
			names[#names + 1] = client.name
		end
	end
	return names
end

---Restart the servers attached to the current buffer.
---Neovim 0.12 can restart a client in place while keeping its buffers; when
---that is unavailable the client is stopped and `vim.lsp.enable()` is asked to
---attach the buffers again.
function M.restart()
	local names = M.names()
	if #names == 0 then
		notify("No language server is attached to this buffer", vim.log.levels.WARN)
		return
	end
	local fallback = {}
	for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
		if type(client._restart) == "function" then
			local ok = pcall(client._restart, client)
			if not ok then
				client:stop()
				fallback[#fallback + 1] = client.name
			end
		else
			client:stop()
			fallback[#fallback + 1] = client.name
		end
	end
	notify("Restarting " .. table.concat(names, ", "))
	if #fallback > 0 then
		vim.defer_fn(function()
			for _, name in ipairs(fallback) do
				vim.lsp.enable(name)
			end
		end, 300)
	end
end

---Stop every server attached to the current buffer.
function M.stop()
	local clients = vim.lsp.get_clients({ bufnr = 0 })
	if #clients == 0 then
		notify("No language server is attached to this buffer", vim.log.levels.WARN)
		return
	end
	local names = M.names()
	for _, client in ipairs(clients) do
		client:stop()
	end
	notify("Stopped " .. table.concat(names, ", "))
end

---Enable a configured server again, or every configured one without a name.
---@param name? string
function M.start(name)
	local lsp = require("nazovim.lsp")
	local servers = lsp.servers()
	if name and name ~= "" then
		if not servers[name] then
			notify("Unknown language server: " .. name, vim.log.levels.WARN)
			return
		end
		vim.lsp.enable(name)
		notify("Enabled " .. name)
		return
	end
	local names = lsp.enabled()
	if #names == 0 then
		notify("No language server executable was found on PATH", vim.log.levels.WARN)
		return
	end
	vim.lsp.enable(names)
	notify("Enabled " .. table.concat(names, ", "))
end

---Register the server lifecycle commands.
function M.setup()
	vim.api.nvim_create_user_command("NazoLspRestart", M.restart, { desc = "Restart the attached language servers" })
	vim.api.nvim_create_user_command("NazoLspStop", M.stop, { desc = "Stop the attached language servers" })
	vim.api.nvim_create_user_command("NazoLspStart", function(opts)
		M.start(opts.args ~= "" and opts.args or nil)
	end, { nargs = "?", desc = "Start a language server, or all configured ones" })
end

return M
