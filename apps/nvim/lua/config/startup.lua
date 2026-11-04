-- Plugin names are the same as in :NazoPlug and nazoplug-lock.json.
-- Use "startup", "on_demand", "VeryLazy", or a Neovim event.
local options = {
	very_lazy_delay_ms = 100,
	plugins = {},
}
local path = vim.env.NAZOVIM_STARTUP_CONFIG
if path and path ~= "" then
	local chunk, err = loadfile(vim.fn.expand(path))
	if not chunk then
		error("NazoVim startup config: " .. tostring(err))
	end
	local configured = chunk()
	if type(configured) ~= "table" then
		error("NazoVim startup config must return a table")
	end
	options = vim.tbl_extend("force", options, configured)
end
local delay = vim.env.NAZOVIM_VERY_LAZY_DELAY_MS
if delay and delay ~= "" then
	options.very_lazy_delay_ms = tonumber(delay) or delay
end
return options
