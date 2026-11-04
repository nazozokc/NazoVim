local M = {}

local features = {
	{ name = "template.commands", phase = "start" },
	{ name = "terminal.commands", phase = "start" },
	{ name = "todo.commands", phase = "start" },
	{ name = "repeat_action", phase = "start" },
	{ name = "substitute", phase = "start" },
	{ name = "pairs", phase = "start" },
	{ name = "surround", phase = "start" },
	{ name = "dial", phase = "start" },
	{ name = "motion", phase = "start" },
	{ name = "marks", phase = "start" },
	{ name = "spell", phase = "start" },
	{ name = "treesitter", phase = "start" },
	{ name = "folding", phase = "start" },
	{ name = "indent", phase = "start" },
	{ name = "icons", phase = "start" },
	{ name = "tabline", phase = "start" },
	{ name = "whichkey", phase = "start" },
	{ name = "zen", phase = "start" },
	{ name = "statuscolumn", phase = "start" },
	{ name = "quickfile", phase = "start" },
	{ name = "diagnostics", phase = "start" },
	{ name = "progress", phase = "start" },
	{ name = "jump", phase = "start" },
	{ name = "tmux_navigation", phase = "start" },
	{ name = "input", phase = "start" },
	{ name = "snippets", phase = "start" },
	{ name = "completion", phase = "start" },
	{ name = "lsp", phase = "start" },
	{ name = "incremental_selection", phase = "start" },
	{ name = "picker", phase = "start" },
	{ name = "colorscheme", phase = "start" },
	{ name = "git", phase = "start" },
	{ name = "github", phase = "start" },
	{ name = "github_metadata", phase = "start" },
	{ name = "github_pr_actions", phase = "start" },
	{ name = "github_pr_details", phase = "start" },
	{ name = "github_projects", phase = "start" },
	{ name = "github_gists", phase = "start" },
	{ name = "github_review", phase = "start" },
	{ name = "github_discussions", phase = "start" },
	{ name = "github_issue_extras", phase = "start" },
	{ name = "color_picker", phase = "start" },
	{ name = "color_highlighter", phase = "start" },
	{ name = "markdown_outline", phase = "start" },
	{ name = "clipboard_history", phase = "start" },
	{ name = "context_hint", phase = "start" },
	{ name = "scope_context", phase = "start" },
	{ name = "pnpm_catalog", phase = "start" },
	{ name = "ts_error_hints", phase = "start" },
	{ name = "coverage", phase = "start" },
	{ name = "lists", phase = "start" },
	{ name = "lint", phase = "start" },
	{ name = "argument_highlights", phase = "start" },
	{ name = "lsp_idle", phase = "start" },
	{ name = "lsp_actions", phase = "start" },
	{ name = "autotag", phase = "start" },
	{ name = "textobjects", phase = "start" },
	{ name = "format", phase = "start" },
	{ name = "action_preview", phase = "start" },
	{ name = "tasks", phase = "start" },
	{ name = "breadcrumb", phase = "start" },
	{ name = "translate", phase = "start" },
	{ name = "outline", phase = "start" },
	{ name = "package_info", phase = "start" },
	{ name = "cmdline_completion", phase = "start" },
	{ name = "markdown_render", phase = "start" },
	{ name = "dap", phase = "start" },
	{ name = "dap_virtual_text", phase = "start" },
	{ name = "animation", phase = "start" },
	{ name = "romaji_search", phase = "start" },
	{ name = "session", phase = "start" },
	{ name = "git_signs", phase = "start" },
	{ name = "git_review", phase = "start" },
	{ name = "lazygit", phase = "start" },
	{ name = "swagger_preview", phase = "start" },
	{ name = "test_runner", phase = "start" },
	{ name = "refactor", phase = "start" },
	{ name = "abbreviations", phase = "start" },
	{ name = "svelte_inspector", phase = "start" },
	{ name = "http_client", phase = "start" },
	{ name = "dap_ui", phase = "start" },
	{ name = "file_browser", phase = "start" },
	{ name = "cmdline_ui", phase = "start" },
	{ name = "notifications", phase = "AfterPlugins" },
	{ name = "peek", phase = "CmdlineEnter" },
	{ name = "statusline", phase = "VimEnter" },
	{ name = "search", phase = "VimEnter" },
	{ name = "colors", phase = "VimEnter" },
	{ name = "todo", phase = "VimEnter" },
	{ name = "references", phase = "VimEnter" },
	{ name = "scrollbar", phase = "VimEnter" },
	{ name = "modes", phase = "VimEnter" },
	{ name = "filename", phase = "VimEnter" },
	{ name = "quickstart", phase = "AfterPlugins" },
	{ name = "dashboard", phase = "start" },
	{ name = "ai_ask", phase = "start" },
	{ name = "codex", phase = "start" },
	{ name = "claudecode", phase = "start" },
	{ name = "opencode", phase = "start" },
}

local function is_disabled(disabled, name)
	if type(disabled) ~= "table" then
		return false
	end
	if disabled[name] == true then
		return true
	end
	for _, disabled_name in ipairs(disabled) do
		if disabled_name == name then
			return true
		end
	end
	return false
end

---Return whether a registered feature is enabled by user configuration.
function M.enabled(name)
	return not is_disabled(vim.g.nazovim_disabled_features, name)
end

local function setup_phase(phase, disabled, context)
	for _, feature in ipairs(features) do
		if feature.phase == phase and not is_disabled(disabled, feature.name) then
			local module = require("nazovim." .. feature.name)
			assert(type(module.setup) == "function", "NazoVim feature lacks setup(): " .. feature.name)
			module.setup(context)
		end
	end
end

---Return the names of independently configurable built-in features.
function M.available()
	local names = {}
	for _, feature in ipairs(features) do
		names[#names + 1] = feature.name
	end
	return names
end

---Start built-in features unless their names are listed in `vim.g.nazovim_disabled_features`.
function M.setup()
	local disabled = vim.g.nazovim_disabled_features
	setup_phase("start", disabled)
	local group = vim.api.nvim_create_augroup("NazoVimFeatures", { clear = true })
	local has_cmdline, has_vimenter = false, false
	for _, feature in ipairs(features) do
		if not is_disabled(disabled, feature.name) then
			has_cmdline = has_cmdline or feature.phase == "CmdlineEnter"
			has_vimenter = has_vimenter or feature.phase == "VimEnter"
		end
	end
	if has_cmdline then
		vim.api.nvim_create_autocmd("CmdlineEnter", {
			group = group,
			pattern = ":",
			once = true,
			callback = function()
				setup_phase("CmdlineEnter", disabled)
			end,
		})
	end
	if has_vimenter then
		vim.api.nvim_create_autocmd("VimEnter", {
			group = group,
			once = true,
			callback = function()
				vim.schedule(function()
					setup_phase("VimEnter", disabled)
				end)
			end,
		})
	end
end

---Start features that require the initialized plugin manager.
function M.setup_after_plugins(manager)
	setup_phase("AfterPlugins", vim.g.nazovim_disabled_features, manager)
end

return M
