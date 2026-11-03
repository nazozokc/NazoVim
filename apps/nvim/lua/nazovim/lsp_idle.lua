local M = {}

local excluded = {
	eslint = true,
	ts_ls = true,
	["typescript-tools"] = true,
}
local timers = {}

local function attached(client)
	return client and next(client.attached_buffers or {}) ~= nil
end

local function cancel(client_id)
	local timer = timers[client_id]
	if timer then
		timer:stop()
		timer:close()
		timers[client_id] = nil
	end
end

local function arm(client_id)
	cancel(client_id)
	local client = vim.lsp.get_client_by_id(client_id)
	if not client or excluded[client.name] or attached(client) then
		return
	end

	local delay = math.max(1000, tonumber(vim.g.nazovim_lsp_idle_timeout_ms) or 300000)
	local timer = vim.uv.new_timer()
	timers[client_id] = timer
	timer:start(
		delay,
		0,
		vim.schedule_wrap(function()
			if timers[client_id] ~= timer then
				return
			end
			timers[client_id] = nil
			timer:close()
			local current = vim.lsp.get_client_by_id(client_id)
			if current and not excluded[current.name] and not attached(current) then
				vim.lsp.stop_client(client_id)
			end
		end)
	)
end

---Schedule unused, non-excluded LSP clients to stop after the idle timeout.
function M.collect()
	for _, client in ipairs(vim.lsp.get_clients()) do
		if not excluded[client.name] and not attached(client) then
			arm(client.id)
		end
	end
end

---Install delayed cleanup after the last buffer detaches from an LSP client.
function M.setup()
	local group = vim.api.nvim_create_augroup("NazoLspIdle", { clear = true })
	vim.api.nvim_create_autocmd("LspAttach", {
		group = group,
		callback = function(event)
			local client_id = event.data and event.data.client_id
			if client_id then
				cancel(client_id)
			end
		end,
	})
	vim.api.nvim_create_autocmd("LspDetach", {
		group = group,
		callback = function(event)
			local client_id = event.data and event.data.client_id
			if client_id then
				vim.defer_fn(function()
					arm(client_id)
				end, 100)
			end
		end,
	})
	vim.api.nvim_create_autocmd("VimLeavePre", {
		group = group,
		callback = function()
			for client_id in pairs(timers) do
				cancel(client_id)
			end
		end,
	})
	vim.api.nvim_create_user_command("NazoLspIdleCleanup", M.collect, {
		desc = "Schedule idle language servers for shutdown",
	})
end

return M
