local U = require("nazoplug.util")

local M = {}

local function is_spec_input(value)
	if type(value) == "string" then
		return true
	end
	return type(value) == "table" and (U.is_list(value) or value.name ~= nil or value.import ~= nil or value[1] ~= nil)
end

-- Normalize the accepted forms:
--   setup("plugins") | setup({ { spec }, ... }) | setup({ spec = ..., ... })
function M.setup(opts)
	if is_spec_input(opts) and not (type(opts) == "table" and opts.spec ~= nil) then
		opts = { spec = opts }
	end
	opts = opts or {}
	local state = require("nazoplug.boot").run(opts)
	if not state then
		return nil
	end
	M.specs = state.specs
	M.by_name = state.by_name
	M.lock = state.lock
	M.lock_path = state.lock_path
	M.config_lock = state.config_lock
	M.pack_dir = state.pack_dir
	M.disabled_plugins = state.disabled_plugins

	vim.api.nvim_exec_autocmds("User", { pattern = "NazoplugDone" })
	vim.api.nvim_exec_autocmds("User", { pattern = "LazyDone" })

	if opts.install and opts.install.missing then
		vim.schedule(function()
			local util = require("nazoplug.util")
			local called, install_ok, _, _, err = pcall(function()
				return require("nazoplug.install").install_missing(M.specs, M.lock, {
					lock_path = M.lock_path,
					save = true,
					by_name = M.by_name,
				})
			end)
			if not called then
				util.error("failed to install missing plugins: " .. tostring(install_ok))
			elseif not install_ok and err then
				util.error("failed to install missing plugins: " .. tostring(err))
			end
		end)
	end

	return M
end

function M.install_missing()
	if not M.specs then
		return nil, "nazoplug is not initialized"
	end
	return require("nazoplug.install").install_missing(
		M.specs,
		M.lock,
		{ lock_path = M.lock_path, save = true, by_name = M.by_name }
	)
end

function M.check()
	require("nazoplug.health").check()
end

return M
