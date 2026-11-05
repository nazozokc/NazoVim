vim.opt.rtp:prepend("apps/nvim")
-- The packaged config ships nazoplug next to the config, so lua_ls picks it up.
vim.opt.rtp:prepend("apps/nazoplug")
require("nazovim").setup()
assert(vim.fn.exists(":ToggleTerm") == 2)
assert(vim.fn.maparg("<CR>", "n") ~= "")
assert(vim.fn.maparg("<S-CR>", "n") ~= "")

-- Hiding a terminal must preserve its buffer and process.
vim.cmd("ToggleTerm")
local terminal = vim.api.nvim_get_current_buf()
assert(vim.bo[terminal].buftype == "terminal")
local job = vim.b[terminal].terminal_job_id
vim.cmd("ToggleTerm")
assert(vim.api.nvim_buf_is_valid(terminal))
vim.cmd("ToggleTerm")
assert(vim.api.nvim_get_current_buf() == terminal)
assert(vim.b[terminal].terminal_job_id == job)
vim.cmd("ToggleTerm")

-- Filename overlays should not create an endless WinClosed redraw loop.
vim.cmd("edit feature-test.txt")
require("nazovim.ui.filename").setup()
vim.wait(200)
assert(#vim.api.nvim_tabpage_list_wins(0) == 2)
vim.cmd("vsplit")
vim.wait(200)
assert(#vim.api.nvim_tabpage_list_wins(0) == 4)

require("nazovim.ui.modes").setup()
assert(vim.api.nvim_get_hl(0, { name = "CursorLineNr" }).fg ~= nil)
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "abc", "def", "ghi" })
vim.api.nvim_win_set_cursor(0, { 1, 0 })
vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<CR>aa", true, false, true), "xt")
assert(vim.deep_equal(vim.api.nvim_win_get_cursor(0), { 1, 0 }))
vim.fn.feedkeys(vim.api.nvim_replace_termcodes(":3<Esc>", true, false, true), "xt")
assert(vim.api.nvim_win_get_cursor(0)[1] == 1)
vim.fn.feedkeys(vim.api.nvim_replace_termcodes(":3<CR>", true, false, true), "xt")
assert(vim.api.nvim_win_get_cursor(0)[1] == 3)
-- Zen mode hides the UI chrome and restores it afterwards.
local zen = require("nazovim.ui.zen")
assert(vim.fn.exists(":NazoZen") == 2, ":NazoZen is missing")
assert(vim.fn.maparg("<leader>z", "n") ~= "", "<leader>z is missing")
vim.o.number = true
vim.o.relativenumber = true
vim.o.signcolumn = "yes"
vim.o.laststatus = 3
vim.diagnostic.enable(true)
zen.toggle()
assert(zen.enabled(), "zen mode should be active")
assert(vim.o.number == false and vim.o.relativenumber == false, "zen mode keeps line numbers")
assert(vim.o.signcolumn == "no", "zen mode keeps the sign column")
assert(vim.o.laststatus == 0, "zen mode keeps the statusline")
assert(vim.diagnostic.is_enabled() == false, "zen mode keeps diagnostics")
zen.toggle()
assert(not zen.enabled(), "zen mode should be inactive")
assert(vim.o.number == true and vim.o.relativenumber == true, "zen mode did not restore line numbers")
assert(vim.o.signcolumn == "yes", "zen mode did not restore the sign column")
assert(vim.o.laststatus == 3, "zen mode did not restore the statusline")
assert(vim.diagnostic.is_enabled() == true, "zen mode did not restore diagnostics")

-- The dashboard replaces the snacks dashboard with the same keys.
local dashboard = require("nazovim.startup.dashboard")
assert(vim.fn.exists(":NazoDashboard") == 2, ":NazoDashboard is missing")
dashboard.show()
local dashboard_buf = vim.api.nvim_get_current_buf()
assert(vim.bo[dashboard_buf].filetype == "nazodashboard", "dashboard filetype")
local dashboard_text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
assert(dashboard_text:find("Recent Files", 1, true), "dashboard has no recent files section")
assert(dashboard_text:find("Keymaps", 1, true), "dashboard has no keymaps section")
local dashboard_keys = {}
for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(dashboard_buf, "n")) do
	dashboard_keys[mapping.lhs] = true
end
for _, key in ipairs({ "e", "f", ".", "r", "z", "q", "<CR>" }) do
	assert(dashboard_keys[key], "dashboard key is missing: " .. key)
end
vim.api.nvim_buf_delete(dashboard_buf, { force = true })
local original_uis = vim.api.nvim_list_uis
vim.api.nvim_list_uis = function()
	return { { width = 80, height = 24 } }
end
vim.cmd.enew()
assert(dashboard.should_show() == true, "dashboard should show for an empty startup buffer")
vim.g.nazovim_quickstart_shown = true
assert(dashboard.should_show() == false, "dashboard must defer to the quickstart screen")
vim.g.nazovim_quickstart_shown = nil
vim.api.nvim_list_uis = original_uis

-- Codex runs the CLI in a reusable floating terminal.
local codex = require("nazovim.ai.codex")
assert(vim.fn.exists(":Codex") == 2, ":Codex is missing")
assert(vim.fn.exists(":CodexToggle") == 2, ":CodexToggle is missing")
local codex_dir = vim.fn.tempname()
vim.fn.mkdir(codex_dir, "p")
local codex_bin = codex_dir .. "/codex"
vim.fn.writefile({ "#!/bin/sh", "printf 'fake codex\\n'", "sleep 30" }, codex_bin)
vim.fn.setfperm(codex_bin, "rwxr-xr-x")
local saved_path = vim.env.PATH
vim.env.PATH = codex_dir .. ":" .. saved_path
codex.open()
assert(codex.is_open(), "codex window did not open")
assert(vim.bo.buftype == "terminal", "codex buffer is not a terminal: " .. vim.bo.buftype)
assert(vim.bo.filetype == "codex", "codex filetype: " .. vim.bo.filetype)
assert(codex.status() == "codex", "codex status component is empty")
codex.toggle()
assert(not codex.is_open(), "codex toggle did not close the window")
codex.toggle()
assert(codex.is_open(), "codex toggle did not reopen the session")
local codex_buf = vim.api.nvim_get_current_buf()
vim.wait(1000, function()
	return vim.api.nvim_buf_get_lines(codex_buf, 0, 1, false)[1] == "fake codex"
end, 20)
assert(vim.api.nvim_buf_get_lines(codex_buf, 0, 1, false)[1] == "fake codex", "codex output missing")
codex.toggle()
vim.env.PATH = saved_path
vim.fn.delete(codex_dir, "rf")

-- Claude Code keeps one session, mentions files and restarts on flags.
local claudecode = require("nazovim.ai.claudecode")
for _, command in ipairs({
	"ClaudeCode",
	"ClaudeCodeToggle",
	"ClaudeCodeFocus",
	"ClaudeCodeAdd",
	"ClaudeCodeSend",
	"ClaudeCodeSelectModel",
}) do
	assert(vim.fn.exists(":" .. command) == 2, ":" .. command .. " is missing")
end
for _, lhs in ipairs({
	"<leader>Cc",
	"<leader>Cf",
	"<leader>Cr",
	"<leader>CC",
	"<leader>Cm",
	"<leader>Cb",
	"<leader>Cs",
}) do
	assert(vim.fn.maparg(lhs, "n") ~= "", lhs .. " is missing")
end
local claude_dir = vim.fn.tempname()
vim.fn.mkdir(claude_dir, "p")
local claude_bin = claude_dir .. "/claude"
vim.fn.writefile({ "#!/bin/sh", 'printf "fake claude args:[%s]\\n" "$*"', "sleep 30" }, claude_bin)
vim.fn.setfperm(claude_bin, "rwxr-xr-x")
local claude_path = vim.env.PATH
vim.env.PATH = claude_dir .. ":" .. claude_path
vim.cmd.edit("feature-test.txt")
local claude_file = vim.api.nvim_get_current_buf()
claudecode.open()
assert(claudecode.is_open(), "claude window did not open")
assert(vim.bo.buftype == "terminal", "claude buffer is not a terminal: " .. vim.bo.buftype)
assert(vim.bo.filetype == "claude", "claude filetype: " .. vim.bo.filetype)
assert(claudecode.status() == "claude", "claude status component is empty")
local claude_buf = vim.api.nvim_get_current_buf()
local function claude_text()
	return table.concat(vim.api.nvim_buf_get_lines(claude_buf, 0, -1, false), "\n")
end
vim.wait(1000, function()
	return claude_text():find("fake claude", 1, true) ~= nil
end, 20)
assert(claude_text():find("fake claude", 1, true), "claude output missing: " .. claude_text())
claudecode.mention(claude_file)
vim.wait(1000, function()
	return claude_text():find("@feature-test.txt", 1, true) ~= nil
end, 20)
assert(claude_text():find("@feature-test.txt", 1, true), "claude mention missing: " .. claude_text())
claudecode.select_model()
vim.wait(1000, function()
	return claude_text():find("/model", 1, true) ~= nil
end, 20)
assert(claude_text():find("/model", 1, true), "claude model picker was not requested")
claudecode.toggle()
assert(not claudecode.is_open(), "claude toggle did not close the window")
claudecode.open({ "--resume" })
assert(claudecode.is_open(), "claude did not restart with a flag")
local restarted = vim.api.nvim_get_current_buf()
vim.wait(1000, function()
	return (vim.api.nvim_buf_get_lines(restarted, 0, 1, false)[1] or ""):find("args:[--resume]", 1, true) ~= nil
end, 20)
assert(
	(vim.api.nvim_buf_get_lines(restarted, 0, 1, false)[1] or ""):find("args:[--resume]", 1, true),
	"claude flag was not passed: " .. vim.inspect(vim.api.nvim_buf_get_lines(restarted, 0, 1, false))
)
claudecode.toggle()
vim.env.PATH = claude_path
vim.fn.delete(claude_dir, "rf")

-- opencode keeps one session, mentions files and restarts on flags.
local opencode = require("nazovim.ai.opencode")
assert(vim.fn.exists(":OpenCode") == 2, ":OpenCode is missing")
assert(vim.fn.exists(":OC") == 2, ":OC is missing")
for _, lhs in ipairs({ "<leader>oa", "<leader>ox" }) do
	assert(vim.fn.maparg(lhs, "n") ~= "", lhs .. " is missing")
end
assert(vim.fn.maparg("<C-.>", "t") ~= "", "<C-.> is missing in terminal mode")
local opencode_dir = vim.fn.tempname()
vim.fn.mkdir(opencode_dir, "p")
local opencode_bin = opencode_dir .. "/opencode"
vim.fn.writefile({ "#!/bin/sh", 'printf "fake opencode args:[%s]\\n" "$*"', "sleep 30" }, opencode_bin)
vim.fn.setfperm(opencode_bin, "rwxr-xr-x")
local opencode_path = vim.env.PATH
vim.env.PATH = opencode_dir .. ":" .. opencode_path
vim.cmd("edit! feature-test.txt")
local opencode_file = vim.api.nvim_get_current_buf()
opencode.open()
assert(opencode.is_open(), "opencode window did not open")
assert(vim.bo.buftype == "terminal", "opencode buffer is not a terminal: " .. vim.bo.buftype)
assert(vim.bo.filetype == "opencode", "opencode filetype: " .. vim.bo.filetype)
assert(opencode.status() == "opencode", "opencode status component is empty")
local opencode_buf = vim.api.nvim_get_current_buf()
local function opencode_text()
	return table.concat(vim.api.nvim_buf_get_lines(opencode_buf, 0, -1, false), "\n")
end
vim.wait(1000, function()
	return opencode_text():find("fake opencode", 1, true) ~= nil
end, 20)
assert(opencode_text():find("fake opencode", 1, true), "opencode output missing: " .. opencode_text())
opencode.mention(opencode_file)
vim.wait(1000, function()
	return opencode_text():find("@feature-test.txt", 1, true) ~= nil
end, 20)
assert(opencode_text():find("@feature-test.txt", 1, true), "opencode mention missing: " .. opencode_text())
opencode.select()
vim.wait(1000, function()
	return opencode_text():find("/", 1, true) ~= nil
end, 20)
assert(opencode_text():find("/", 1, true), "opencode command palette was not requested")
opencode.toggle()
assert(not opencode.is_open(), "opencode toggle did not close the window")
opencode.open({ "--continue" })
assert(opencode.is_open(), "opencode did not restart with a flag")
local opencode_restarted = vim.api.nvim_get_current_buf()
vim.wait(1000, function()
	return (vim.api.nvim_buf_get_lines(opencode_restarted, 0, 1, false)[1] or ""):find("args:[--continue]", 1, true)
		~= nil
end, 20)
assert(
	(vim.api.nvim_buf_get_lines(opencode_restarted, 0, 1, false)[1] or ""):find("args:[--continue]", 1, true),
	"opencode flag was not passed: " .. vim.inspect(vim.api.nvim_buf_get_lines(opencode_restarted, 0, 1, false))
)
opencode.toggle()
vim.env.PATH = opencode_path
vim.fn.delete(opencode_dir, "rf")

-- Completion uses Neovim's built-in popup with LSP, snippets, buffer words and paths.
local completion = require("nazovim.completion")
local completeopt = vim.opt.completeopt:get()
for _, flag in ipairs({ "menu", "menuone", "noselect", "popup" }) do
	assert(vim.tbl_contains(completeopt, flag), "completeopt is missing " .. flag)
end
for _, lhs in ipairs({ "<C-Space>", "<Tab>", "<S-Tab>", "<CR>" }) do
	assert(vim.fn.maparg(lhs, "i") ~= "", lhs .. " is missing in insert mode")
end
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "alpha alphabet beta" })
local buffer_items = completion.items("alph")
local buffer_words = {}
for _, item in ipairs(buffer_items) do
	if item.menu == "[BUF]" then
		buffer_words[item.word] = true
	end
end
assert(buffer_words["alphabet"], "completion.items missed a buffer word: " .. vim.inspect(buffer_items))
assert(not buffer_words["beta"], "completion.items returned an unrelated buffer word")
local path_items = completion.items("apps/nvim/lua/nazovim/github")
local found_path = false
for _, item in ipairs(path_items) do
	if item.menu == "[PATH]" and item.word:find("github", 1, true) then
		found_path = true
	end
end
assert(found_path, "completion.items missed file paths: " .. vim.inspect(path_items))
local saved_snippet_dir = vim.g.nazovim_snippet_dir
vim.g.nazovim_snippet_dir = "apps/nvim/snippets"
require("nazovim.completion.snippets").reload()
vim.bo.filetype = "lua"
local snippet_items = completion.items("f")
local found_snippet = false
for _, item in ipairs(snippet_items) do
	if item.menu == "[SNIP]" and item.word == "fn" then
		found_snippet = true
	end
end
assert(found_snippet, "completion.items missed snippets: " .. vim.inspect(snippet_items))
vim.bo.filetype = ""
vim.g.nazovim_snippet_dir = saved_snippet_dir

-- Language servers come from PATH; mason is gone.
local lsp = require("nazovim.lsp")
assert(vim.fn.exists(":NazoLspInfo") == 2, ":NazoLspInfo is missing")
local lsp_servers = lsp.servers()
for _, name in ipairs({ "lua_ls", "clangd", "html", "nixd", "solargraph", "zls", "ts_ls", "rust_analyzer", "jdtls" }) do
	local server = lsp_servers[name]
	assert(server, "lsp server is missing: " .. name)
	assert(lsp.binary(server), "lsp server has no executable: " .. name)
	assert(type(server.cmd) == "table" or type(server.cmd) == "function", "lsp server has no cmd: " .. name)
	assert(#server.filetypes > 0, "lsp server has no filetypes: " .. name)
end
assert(
	vim.tbl_get(vim.lsp.config, "lua_ls", "cmd", 1) == "lua-language-server",
	"lua_ls was not registered with vim.lsp.config"
)
assert(
	vim.tbl_get(
		vim.lsp.config,
		"lua_ls",
		"capabilities",
		"textDocument",
		"completion",
		"completionItem",
		"snippetSupport"
	) == true,
	"lua_ls capabilities lost snippetSupport"
)
local lua_library = vim.tbl_get(vim.lsp.config, "lua_ls", "settings", "Lua", "workspace", "library") or {}
assert(vim.tbl_contains(lua_library, vim.env.VIMRUNTIME), "lua_ls is missing the Neovim runtime library")
local nazoplug_library = false
for _, path in ipairs(lua_library) do
	if vim.fn.filereadable(path .. "/nazoplug/spec.lua") == 1 then
		nazoplug_library = true
	end
end
assert(nazoplug_library, "lua_ls is missing the nazoplug library: " .. vim.inspect(lua_library))
for _, name in ipairs(lsp.enabled()) do
	assert(vim.fn.executable(lsp.binary(lsp_servers[name])) == 1, name .. " is enabled without an executable")
end
for _, name in ipairs(lsp.missing()) do
	assert(
		vim.fn.executable(lsp.binary(lsp_servers[name])) == 0,
		name .. " is reported missing but its executable exists"
	)
end
vim.api.nvim_exec_autocmds("LspAttach", { buffer = vim.api.nvim_get_current_buf() })
for _, lhs in ipairs({ "K", "<leader>ls", "<leader>ld", "<leader>gr" }) do
	assert(vim.fn.maparg(lhs, "n") ~= "", "lsp keymap is missing: " .. lhs)
end
-- ts_ls (typescript-language-server) replaces typescript-tools.nvim.
assert(lsp_servers.ts_ls, "lsp server is missing: ts_ls")
assert(
	vim.tbl_get(vim.lsp.config, "ts_ls", "cmd", 1) == "typescript-language-server",
	"ts_ls was not registered with vim.lsp.config"
)
vim.cmd("enew")
lsp.attach_keymaps(0, { name = "ts_ls" })
for _, lhs in ipairs({ "<leader>oi", "<leader>ru" }) do
	assert(vim.fn.maparg(lhs, "n") ~= "", "ts_ls keymap is missing: " .. lhs)
end
vim.cmd("enew")
lsp.attach_keymaps(0, { name = "lua_ls" })
for _, lhs in ipairs({ "<leader>oi", "<leader>ru" }) do
	assert(vim.fn.maparg(lhs, "n") == "", "ts_ls keymap leaked to another server: " .. lhs)
end
-- rustaceanvim is replaced by rust_analyzer plus a runnables picker.
assert(lsp_servers.rust_analyzer, "lsp server is missing: rust_analyzer")
assert(
	vim.tbl_get(vim.lsp.config, "rust_analyzer", "cmd", 1) == "rust-analyzer",
	"rust_analyzer was not registered with vim.lsp.config"
)
assert(
	vim.tbl_get(vim.lsp.config, "rust_analyzer", "settings", "rust-analyzer", "cargo", "allFeatures") == true,
	"rust_analyzer lost cargo.allFeatures"
)
assert(
	vim.deep_equal(
		lsp.rust_command({ args = { cargoArgs = { "run", "--bin", "app" }, executableArgs = { "--verbose" } } }),
		{ "cargo", "run", "--bin", "app", "--", "--verbose" }
	),
	"rust_command did not build the cargo invocation"
)
assert(
	vim.deep_equal(
		lsp.rust_command({ args = { overrideCargo = "rustup", cargoArgs = { "test" } } }),
		{ "rustup", "test" }
	),
	"rust_command ignored overrideCargo"
)
vim.cmd("enew")
lsp.attach_keymaps(0, { name = "rust_analyzer" })
assert(vim.fn.maparg("<leader>rr", "n") ~= "", "rust_analyzer keymap is missing: <leader>rr")
vim.cmd("enew")
lsp.attach_keymaps(0, { name = "lua_ls" })
assert(vim.fn.maparg("<leader>rr", "n") == "", "rust_analyzer keymap leaked to another server")

-- Git operations run the git CLI instead of vim-fugitive.
local git = require("nazovim.git")
for _, command in ipairs({
	"Git",
	"NazoGitStatus",
	"NazoGitStage",
	"NazoGitUnstage",
	"NazoGitDiff",
	"NazoGitLog",
	"NazoGitBlame",
}) do
	assert(vim.fn.exists(":" .. command) == 2, ":" .. command .. " is missing")
end
for _, lhs in ipairs({ "<leader>gs", "<leader>ga", "<leader>gu", "<leader>gl" }) do
	assert(vim.fn.maparg(lhs, "n") ~= "", lhs .. " is missing")
end
local git_dir = vim.fn.tempname()
vim.fn.mkdir(git_dir, "p")
local function git_run(arguments)
	local command = { "git", "-C", git_dir }
	vim.list_extend(command, arguments)
	local result = vim.system(command, { text = true }):wait(10000)
	assert(result.code == 0, "git " .. table.concat(arguments, " ") .. " failed: " .. tostring(result.stderr))
	return result.stdout or ""
end
git_run({ "init", "-q", "." })
git_run({ "config", "user.email", "test@example.com" })
git_run({ "config", "user.name", "Test" })
vim.fn.writefile({ "alpha" }, git_dir .. "/note.txt")
git_run({ "add", "note.txt" })
git_run({ "commit", "-qm", "first commit" })
vim.fn.writefile({ "alpha", "beta" }, git_dir .. "/note.txt")
vim.fn.writefile({ "new" }, git_dir .. "/fresh.txt")
local git_items = git.status_items(git_dir)
assert(#git_items == 2, "git status items: " .. vim.inspect(git_items))
local git_status_buf = git.show_status(git_dir)
assert(vim.bo[git_status_buf].filetype == "nazogitstatus", "git status filetype")
local git_status_text = table.concat(vim.api.nvim_buf_get_lines(git_status_buf, 0, -1, false), "\n")
assert(git_status_text:find("note.txt", 1, true), "git status buffer missed note.txt: " .. git_status_text)
assert(git.stage("fresh.txt", git_dir), "git stage failed")
local staged = git.status_items(git_dir)
local staged_code = nil
for _, item in ipairs(staged) do
	if item.path == "fresh.txt" then
		staged_code = item.code
	end
end
assert(staged_code == "A ", "git stage did not stage fresh.txt: " .. vim.inspect(staged))
assert(git.unstage("fresh.txt", git_dir), "git unstage failed")
local unstaged_code = nil
for _, item in ipairs(git.status_items(git_dir)) do
	if item.path == "fresh.txt" then
		unstaged_code = item.code
	end
end
assert(unstaged_code == "??", "git unstage did not unstage fresh.txt: " .. tostring(unstaged_code))
local git_diff = git.show_diff("note.txt", git_dir)
assert(git_diff:find("+beta", 1, true), "git diff missed the change: " .. git_diff)
local git_log = git.log_entries(git_dir)
assert(#git_log == 1 and git_log[1].subject:find("first commit", 1, true), "git log: " .. vim.inspect(git_log))
local git_show = git.show_commit(git_log[1].hash, git_dir)
assert(git_show:find("first commit", 1, true), "git show missed the commit subject")
vim.cmd("edit " .. vim.fn.fnameescape(git_dir .. "/note.txt"))
vim.api.nvim_win_set_cursor(0, { 2, 0 })
local git_blame = git.blame_line(git_dir)
assert(git_blame ~= "", "git blame returned nothing")
assert(git.relative(git_dir) == "note.txt", "git relative path: " .. tostring(git.relative(git_dir)))
vim.fn.delete(git_dir, "rf")

-- File icons come from the built-in devicons replacement.
local icons = require("nazovim.ui.icons")
assert(icons.has_loaded(), "icons.has_loaded returned false")
local lua_icon, lua_group = icons.get_icon("init.lua")
assert(lua_icon ~= "" and lua_group ~= "", "get_icon returned nothing for a lua file")
assert(icons.get_icon("Makefile") ~= "", "get_icon missed a known filename")
assert(icons.get_icon("README.md") ~= "", "get_icon missed README.md")
assert(icons.get_icon_by_filetype("lua") == lua_icon, "get_icon_by_filetype disagrees with get_icon")
assert(icons.get_icon_by_filetype("not-a-filetype") ~= "", "get_icon_by_filetype has no fallback")
assert(icons.get_icon("notes.zzz") ~= "", "get_icon has no fallback for unknown extensions")
icons.set_icon({ extension = "zzz", icon = "Z", color = "#ffffff" })
assert(icons.get_icon("notes.zzz") == "Z", "set_icon did not override the extension icon")
assert(icons.get_icons_by_extension().lua ~= nil, "get_icons_by_extension is empty")
assert(icons.get_icons_by_filename()["makefile"] ~= nil, "get_icons_by_filename is empty")
assert(vim.api.nvim_get_hl(0, { name = lua_group }).fg ~= nil, "the icon highlight group is undefined")
vim.cmd("edit icon-test.lua")
local tabline = require("nazovim.ui.tabline")
tabline.setup()
assert(tabline.render():find(lua_icon, 1, true), "the tabline is missing the file icon")

-- NazoAI asks a CLI non-interactively and streams the answer into the panel.
local ai_ask = require("nazovim.ai.ask")
for _, command in ipairs({ "NazoAI", "NazoAIEdit", "NazoAIStop", "NazoAIToggle", "NazoAIFiles" }) do
	assert(vim.fn.exists(":" .. command) == 2, ":" .. command .. " is missing")
end
for _, lhs in ipairs({
	"<leader>aa",
	"<leader>an",
	"<leader>ae",
	"<leader>at",
	"<leader>af",
	"<leader>aS",
	"<leader>ac",
	"<leader>aB",
	"<leader>aC",
	"<leader>a?",
	"<leader>ah",
}) do
	assert(vim.fn.maparg(lhs, "n") ~= "", lhs .. " is missing")
end
assert(
	vim.deep_equal(ai_ask.code_blocks("a\n```lua\nx = 1\n```\nb\n```\ny\n```"), { "x = 1", "y" }),
	"ai_ask.code_blocks: " .. vim.inspect(ai_ask.code_blocks("a\n```lua\nx = 1\n```\nb\n```\ny\n```"))
)
assert(
	ai_ask.build_prompt("why?", { { path = "a.lua", filetype = "lua", body = "x" } })
		== "why?\n\n### a.lua\n```lua\nx\n```",
	"ai_ask.build_prompt: " .. ai_ask.build_prompt("why?", { { path = "a.lua", filetype = "lua", body = "x" } })
)
assert(
	vim.deep_equal(
		ai_ask.command("codex", "hi"),
		{ "codex", "exec", "--skip-git-repo-check", "--color", "never", "hi" }
	),
	"ai_ask.command codex"
)
assert(vim.deep_equal(ai_ask.command("claude", "hi"), { "claude", "-p", "hi" }), "ai_ask.command claude")
assert(vim.deep_equal(ai_ask.command("opencode", "hi"), { "opencode", "run", "hi" }), "ai_ask.command opencode")
assert(ai_ask.command("nope", "hi") == nil, "ai_ask.command accepted an unknown provider")
local ai_dir = vim.fn.tempname()
vim.fn.mkdir(ai_dir, "p")
local ai_bin = ai_dir .. "/claude"
vim.fn.writefile({
	"#!/bin/sh",
	"echo 'answer:'",
	"echo",
	"echo '```lua'",
	"echo 'local answer = 42'",
	"echo '```'",
}, ai_bin)
vim.fn.setfperm(ai_bin, "rwxr-xr-x")
local ai_path = vim.env.PATH
vim.env.PATH = ai_dir .. ":" .. ai_path
vim.g.nazovim_ai_provider = "claude"
assert(ai_ask.provider() == "claude", "ai_ask.provider: " .. tostring(ai_ask.provider()))
vim.cmd("edit! feature-test.txt")
ai_ask.add_current()
assert(#ai_ask.files() == 1, "ai_ask.add_current did not attach the buffer")
assert(ai_ask.ask("explain") ~= nil, "ai_ask.ask did not start a job")
local function ai_text()
	return table.concat(vim.api.nvim_buf_get_lines(ai_ask.buffer(), 0, -1, false), "\n")
end
vim.wait(5000, function()
	return ai_text():find("local answer = 42", 1, true) ~= nil
end, 20)
assert(ai_text():find("local answer = 42", 1, true), "ai_ask did not stream the answer: " .. ai_text())
assert(ai_text():find("explain", 1, true), "ai_ask panel lost the question: " .. ai_text())
assert(vim.bo[ai_ask.buffer()].filetype == "markdown", "ai_ask panel filetype")
assert(ai_ask.is_open(), "ai_ask panel did not open")
ai_ask.toggle()
assert(not ai_ask.is_open(), "ai_ask toggle did not hide the panel")
ai_ask.focus()
assert(ai_ask.is_open(), "ai_ask focus did not reopen the panel")
ai_ask.toggle()
assert(not ai_ask.is_open(), "ai_ask panel stayed open")
-- apply_code replaces a range.
vim.cmd("enew")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "old" })
assert(ai_ask.apply_code(0, 0, -1, "new\ncode"), "ai_ask.apply_code failed")
assert(
	vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "new", "code" }),
	"ai_ask.apply_code result: " .. vim.inspect(vim.api.nvim_buf_get_lines(0, 0, -1, false))
)
-- edit applies the first fenced block to the target buffer.
vim.cmd("enew")
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "placeholder" })
local ai_edit_buf = vim.api.nvim_get_current_buf()
local real_input = vim.fn.input
vim.fn.input = function()
	return "rewrite"
end
ai_ask.edit()
vim.wait(5000, function()
	return vim.api.nvim_buf_get_lines(ai_edit_buf, 0, -1, false)[1] == "local answer = 42"
end, 20)
vim.fn.input = real_input
assert(
	vim.deep_equal(vim.api.nvim_buf_get_lines(ai_edit_buf, 0, -1, false), { "local answer = 42" }),
	"ai_ask.edit did not apply the answer: " .. vim.inspect(vim.api.nvim_buf_get_lines(ai_edit_buf, 0, -1, false))
)
ai_ask.toggle()
-- select_provider lists the available CLIs.
local real_select = vim.ui.select
local offered
vim.ui.select = function(items, _, on_choice)
	offered = items
	on_choice(items[#items])
end
ai_ask.select_provider()
vim.ui.select = real_select
assert(offered and #offered > 0, "ai_ask.select_provider listed nothing")
assert(ai_ask.stop() == false, "ai_ask.stop reported a job while idle")
ai_ask.clear_files()
assert(#ai_ask.files() == 0, "ai_ask.clear_files did not clear the list")
vim.env.PATH = ai_path
vim.g.nazovim_ai_provider = nil
vim.fn.delete(ai_dir, "rf")

-- The built-in DAP client speaks the Debug Adapter Protocol over stdio.
local dap = require("nazovim.dap")
dap.setup()
for _, command in ipairs({
	"NazoDapStart",
	"NazoDapStop",
	"NazoDapContinue",
	"NazoDapNext",
	"NazoDapStepIn",
	"NazoDapStepOut",
	"NazoDapBreakpoints",
	"NazoDapEval",
	"NazoDapInfo",
}) do
	assert(vim.fn.exists(":" .. command) == 2, ":" .. command .. " is missing")
end
for _, lhs in ipairs({
	"<F5>",
	"<F10>",
	"<F11>",
	"<F12>",
	"<leader>db",
	"<leader>dB",
	"<leader>dl",
	"<leader>de",
	"<leader>dq",
	"<leader>du",
}) do
	assert(vim.fn.maparg(lhs, "n") ~= "", lhs .. " is missing")
end
-- Framing round-trip, including a message split across chunks.
local framed = dap.encode({ seq = 1, type = "request", command = "initialize" })
assert(framed:sub(1, 15) == "Content-Length:", "dap.encode header: " .. framed)
local parser = { buffer = "" }
local split = math.floor(#framed / 2)
assert(#dap.parse(parser, framed:sub(1, split)) == 0, "dap.parse decoded a partial message")
local decoded = dap.parse(parser, framed:sub(split + 1))
assert(#decoded == 1, "dap.parse returned " .. #decoded .. " messages")
assert(decoded[1].command == "initialize", "dap.parse command: " .. tostring(decoded[1].command))
assert(parser.buffer == "", "dap.parse left " .. vim.inspect(parser.buffer) .. " in the buffer")
-- Launch configurations expand ${file} and ${workspaceFolder}.
local dap_dir = vim.fn.tempname()
vim.fn.mkdir(dap_dir, "p")
local sample = dap_dir .. "/sample.js"
vim.fn.writefile({ "function main() {", "  const x = 1;", "  console.log(x);", "}", "main();" }, sample)
vim.cmd("edit! " .. sample)
vim.bo.filetype = "javascript"
local resolved = dap.resolve(dap.configurations.javascript[1])
assert(resolved.program == sample, "dap.resolve program: " .. tostring(resolved.program))
assert(resolved.cwd == vim.fn.getcwd(), "dap.resolve cwd: " .. tostring(resolved.cwd))
assert(dap.select_configuration() ~= nil, "dap.select_configuration returned nil for javascript")
vim.bo.filetype = "text"
assert(dap.select_configuration() == nil, "dap.select_configuration accepted a text buffer")
vim.bo.filetype = "javascript"
-- A fake adapter exercises the full request/event cycle without js-debug.
local adapter_script = dap_dir .. "/adapter.lua"
local adapter_source = ([[
local buffer = ""
local seq = 0
local function read_message()
  while true do
    local header_end = buffer:find("\r\n\r\n", 1, true)
    if header_end then
      local header = buffer:sub(1, header_end - 1)
      local length = tonumber(header:match("[Cc]ontent%-[Ll]ength:%s*(%d+)"))
      if length then
        local start = header_end + 4
        if #buffer >= start + length - 1 then
          local body = buffer:sub(start, start + length - 1)
          buffer = buffer:sub(start + length)
          return vim.json.decode(body)
        end
      else
        buffer = buffer:sub(header_end + 4)
      end
    end
    local chunk = io.read(1)
    if not chunk then
      return nil
    end
    buffer = buffer .. chunk
  end
end
local function send(message)
  seq = seq + 1
  message.seq = seq
  local body = vim.json.encode(message)
  io.write("Content-Length: " .. #body .. "\r\n\r\n" .. body)
  io.flush()
end
local function respond(request, body)
  send({ type = "response", request_seq = request.seq, command = request.command, success = true, body = body or {} })
end
while true do
  local message = read_message()
  if not message then
    break
  end
  if message.type == "request" then
    local command = message.command
    if command == "initialize" then
      respond(message, { supportsConfigurationDoneRequest = true })
      send({ type = "event", event = "initialized", body = {} })
    elseif command == "launch" then
      respond(message)
      send({ type = "event", event = "stopped", body = { reason = "breakpoint", threadId = 1 } })
    elseif command == "stackTrace" then
      respond(message, {
        stackFrames = {
          { id = 1, name = "main", line = 2, column = 3, source = { path = "__SAMPLE__" } },
          { id = 2, name = "caller", line = 1, column = 1, source = { path = "__SAMPLE__" } },
        },
      })
    elseif command == "scopes" then
      respond(message, { scopes = { { name = "Local", variablesReference = 10 } } })
    elseif command == "variables" then
      respond(message, { variables = { { name = "x", value = "1", variablesReference = 0, type = "number" } } })
    elseif command == "evaluate" then
      respond(message, { result = "42", variablesReference = 0 })
    elseif command == "setBreakpoints" then
      local list = {}
      for _, breakpoint in ipairs((message.arguments or {}).breakpoints or {}) do
        list[#list + 1] = { id = breakpoint.line, verified = true, line = breakpoint.line }
      end
      respond(message, { breakpoints = list })
    elseif command == "disconnect" then
      respond(message)
      break
    else
      respond(message)
    end
  end
end
]]):gsub("__SAMPLE__", function()
	return sample
end)
vim.fn.writefile(vim.split(adapter_source, "\n", { plain = true }), adapter_script)
local adapter = { transport = "stdio", cmd = { vim.v.progpath, "--headless", "-u", "NONE", "-l", adapter_script } }
assert(vim.fn.executable(adapter.cmd[1]) == 1, "the test adapter is not executable: " .. adapter.cmd[1])
local session = dap.start({
	config = {
		type = "pwa-node",
		request = "launch",
		name = "test",
		program = sample,
		cwd = dap_dir,
	},
	adapter = adapter,
})
assert(session ~= nil, "dap.start returned nil")
assert(dap.session() == session, "dap.session did not return the new session")
vim.wait(15000, function()
	return session.current_frame ~= nil
end, 25)
assert(session.current_frame ~= nil, "the session never stopped on a frame")
assert(session.current_frame.name == "main", "frame name: " .. tostring(session.current_frame.name))
assert(session.current_frame.line == 2, "frame line: " .. tostring(session.current_frame.line))
assert(#session.stack == 2, "stack size: " .. #session.stack)
vim.wait(5000, function()
	local scope = session.current_frame.scopes and session.current_frame.scopes[1]
	return scope and scope.variables and #scope.variables > 0
end, 25)
local scope = session.current_frame.scopes and session.current_frame.scopes[1]
assert(scope ~= nil, "dap did not fetch scopes")
assert(scope.name == "Local", "scope name: " .. tostring(scope.name))
assert(scope.variables[1].name == "x", "variable name: " .. tostring(scope.variables[1].name))
local evaluated
session:request("evaluate", { expression = "1+1", frameId = 1, context = "repl" }, function(err, body)
	evaluated = err and ("error: " .. tostring(err.message)) or (body and body.result)
end)
vim.wait(5000, function()
	return evaluated ~= nil
end, 25)
assert(evaluated == "42", "dap evaluate: " .. tostring(evaluated))
-- Breakpoints are tracked per file and mirrored into the adapter.
vim.api.nvim_win_set_cursor(0, { 2, 0 })
assert(dap.toggle_breakpoint() == true, "dap.toggle_breakpoint did not add")
local grouped = dap.breakpoints.get()
assert(grouped[vim.fn.bufnr(sample)] ~= nil, "dap.breakpoints.get did not group by buffer")
assert(
	grouped[vim.fn.bufnr(sample)][1].line == 2,
	"breakpoint line: " .. tostring(grouped[vim.fn.bufnr(sample)][1].line)
)
assert(dap.toggle_breakpoint() == false, "dap.toggle_breakpoint did not remove")
assert(dap.toggle_breakpoint("x > 1") == true, "dap.toggle_breakpoint did not add a conditional")
assert(dap.breakpoints.all()[sample][1].condition == "x > 1", "the breakpoint condition was not stored")
local breakpoint_buf = dap.show_breakpoints()
assert(
	vim.bo[breakpoint_buf].filetype == "nazodapbreakpoints",
	"breakpoint buffer filetype: " .. vim.bo[breakpoint_buf].filetype
)
local breakpoint_lines = vim.api.nvim_buf_get_lines(breakpoint_buf, 0, -1, false)
assert(
	table.concat(breakpoint_lines, "\n"):find("if x > 1", 1, true) ~= nil,
	"the breakpoint list lost the condition: " .. vim.inspect(breakpoint_lines)
)
vim.api.nvim_win_close(vim.api.nvim_get_current_win(), true)
-- Session controls issue their requests without erroring.
dap.step_over()
dap.step_into()
dap.step_out()
dap.up()
dap.down()
dap.continue()
dap.terminate()
vim.wait(5000, function()
	return dap.session() == nil
end, 25)
assert(dap.session() == nil, "dap.terminate did not clear the session")
-- A missing adapter is reported instead of crashing.
local missing = dap.start({
	config = { type = "pwa-node", request = "launch", name = "missing", program = sample },
	adapter = { transport = "stdio", cmd = { dap_dir .. "/no-such-adapter" } },
})
assert(missing == nil, "dap.start accepted a missing adapter")
dap.breakpoints.all()[sample] = nil
vim.cmd("silent! bwipeout! " .. breakpoint_buf)
vim.fn.delete(dap_dir, "rf")

-- js-debug launches the debuggee through a reverse `startDebugging` request: the
-- client must answer it and open a child session on a second connection.
local function stub_transport()
	local transport = { sent = {} }
	transport.send = function(text)
		transport.sent[#transport.sent + 1] = text
	end
	transport.close = function()
		transport.closed = true
	end
	transport.set_handler = function(handler)
		transport.handler = handler
	end
	return transport
end
local function pump(condition)
	vim.wait(5000, condition or function()
		return false
	end, 5)
end
local function stub_messages(transport)
	local messages = {}
	local state = { buffer = "" }
	for _, text in ipairs(transport.sent) do
		vim.list_extend(messages, dap.parse(state, text))
	end
	return messages
end
local parent_transport = stub_transport()
local child_transport = stub_transport()
parent_transport.connection = function()
	return child_transport
end
local parent = dap.open(parent_transport, { type = "pwa-node", request = "launch", name = "parent" }, "launch")
local parent_messages = stub_messages(parent_transport)
assert(#parent_messages == 1, "dap.open sent " .. #parent_messages .. " messages")
assert(parent_messages[1].command == "initialize", "dap.open initialize: " .. tostring(parent_messages[1].command))
assert(parent_messages[1].arguments.adapterID == "pwa-node", "dap.open adapterID")
parent_transport.handler({ type = "response", request_seq = 1, success = true, command = "initialize", body = {} })
pump(function()
	return #parent_transport.sent >= 2
end)
parent_messages = stub_messages(parent_transport)
assert(parent_messages[2].command == "launch", "dap.open launch: " .. tostring(parent_messages[2].command))
-- The reverse request is accepted and spawns the child.
parent:adapter_request({
	seq = 9,
	command = "startDebugging",
	arguments = { request = "launch", configuration = { type = "pwa-node", name = "child", __pendingTargetId = "abc" } },
})
local response = stub_messages(parent_transport)[3]
assert(response.type == "response" and response.request_seq == 9, "startDebugging response missing")
assert(response.success == true, "startDebugging was rejected")
assert(parent.child ~= nil, "startDebugging did not spawn a child session")
assert(dap.session() == parent.child, "dap.session did not prefer the child")
assert(parent.child.config.name == "child", "child configuration: " .. tostring(parent.child.config.name))
local child_messages = stub_messages(child_transport)
assert(#child_messages == 1 and child_messages[1].command == "initialize", "the child never initialized")
child_transport.handler({ type = "response", request_seq = 1, success = true, command = "initialize", body = {} })
pump(function()
	return #child_transport.sent >= 2
end)
child_messages = stub_messages(child_transport)
assert(child_messages[2].command == "launch", "the child never launched")
assert(
	child_messages[2].arguments.__pendingTargetId == "abc",
	"the child launch lost __pendingTargetId: " .. vim.inspect(child_messages[2].arguments)
)
-- The child's events drive the UI.
child_transport.handler({ type = "event", event = "stopped", body = { threadId = 0, reason = "breakpoint" } })
pump(function()
	return #child_transport.sent >= 3
end)
child_messages = stub_messages(child_transport)
assert(
	child_messages[3].command == "stackTrace",
	"the child did not request a stack: " .. tostring(child_messages[3].command)
)
assert(child_messages[3].arguments.threadId == 0, "the child used the wrong thread id")
child_transport.handler({
	type = "response",
	request_seq = child_messages[3].seq,
	success = true,
	command = "stackTrace",
	body = { stackFrames = { { id = 7, name = "childFrame", line = 4, column = 1, source = { path = sample } } } },
})
pump(function()
	return parent.child.current_frame ~= nil
end)
assert(parent.child.current_frame ~= nil, "the child never selected a frame")
assert(parent.child.current_frame.name == "childFrame", "child frame: " .. tostring(parent.child.current_frame.name))
-- Unsupported reverse requests are still rejected.
parent:adapter_request({ seq = 11, command = "runInTerminal", arguments = {} })
local rejected = stub_messages(parent_transport)
local last = rejected[#rejected]
assert(last.request_seq == 11 and last.success == false, "runInTerminal was not rejected")
dap.close_all()
assert(parent.closed, "dap.close_all left the parent open")
assert(parent.child.closed, "dap.close_all left the child open")
assert(dap.session() == nil, "dap.session survived dap.close_all")

-- Treesitter highlighting is started by the built-in module, not a plugin.
local treesitter = require("nazovim.edit.treesitter")
local locals_index = require("nazovim.lib.locals")
assert(vim.fn.exists(":NazoTreesitterInfo") == 2, ":NazoTreesitterInfo is missing")
assert(#vim.api.nvim_get_autocmds({ group = "NazoTreesitter" }) == 1, "the treesitter FileType autocmd is missing")
assert(vim.islist(treesitter.directories()), "treesitter.directories does not return a list")
assert(treesitter.available("not-a-language") == false, "treesitter.available accepted a bogus language")
assert(type(locals_index.find_definition) == "function", "locals.find_definition is missing")
assert(type(locals_index.find_usages) == "function", "locals.find_usages is missing")
vim.cmd("edit treesitter-test.lua")
-- Headless runs skip filetype detection, so set it explicitly.
vim.bo.filetype = "lua"
assert(treesitter.language() == "lua", "treesitter.language: " .. tostring(treesitter.language()))
local attached = treesitter.attach()
if treesitter.available("lua") then
	assert(attached == "lua", "treesitter.attach: " .. tostring(attached))
	assert(treesitter.attached() == "lua", "treesitter.attached disagrees with attach")
	assert(vim.tbl_contains(treesitter.enabled(), "lua"), "treesitter.enabled missed lua")
	assert(
		vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] ~= nil,
		"treesitter.attach did not start the highlighter"
	)
	-- The locals index needs a `locals` query. Supply a minimal one so the test
	-- does not depend on a query corpus being installed.
	local query_dir = vim.fn.tempname()
	vim.fn.mkdir(query_dir .. "/queries/lua", "p")
	vim.fn.writefile({
		"(chunk) @local.scope",
		"(assignment_statement (variable_list (identifier) @local.definition))",
		"(identifier) @local.reference",
	}, query_dir .. "/queries/lua/locals.scm")
	vim.opt.runtimepath:prepend(query_dir)
	assert(vim.treesitter.query.get("lua", "locals") ~= nil, "the locals query was not found")
	vim.api.nvim_buf_set_lines(0, 0, -1, false, { "local count = 0", "print(count)" })
	local node = vim.treesitter.get_node({ bufnr = 0, pos = { 0, 7 } })
	assert(node, "no treesitter node under the cursor")
	local definition, scope, kind = locals_index.find_definition(node, 0)
	assert(kind == "definition", "locals.find_definition kind: " .. tostring(kind))
	assert(vim.treesitter.get_node_text(definition, 0) == "count", "locals.find_definition text")
	local usages = locals_index.find_usages(definition, scope, 0)
	assert(#usages >= 1, "locals.find_usages missed the usage")
	assert(vim.treesitter.get_node_text(usages[#usages], 0) == "count", "locals.find_usages returned another symbol")
else
	assert(attached == nil, "treesitter.attach attached without a parser")
end

-- The built-in status column keeps signs, folds and numbers in one column.
assert(vim.o.statuscolumn ~= "", "status column is empty")
assert(vim.o.statuscolumn:find("%s", 1, true), "status column has no sign item")
assert(vim.o.statuscolumn:find("%C", 1, true), "status column has no fold item")
vim.cmd("NazoStatuscolumn!")
assert(vim.o.statuscolumn == "", "NazoStatuscolumn! should reset the column")
vim.cmd("NazoStatuscolumn")
assert(vim.o.statuscolumn ~= "", "NazoStatuscolumn should restore the column")

-- Quickfile creates missing parent directories when the file is written.
local quickfile_dir = vim.fn.tempname()
local quickfile_path = quickfile_dir .. "/nested/deep/note.txt"
vim.cmd.edit(quickfile_path)
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "hello" })
vim.cmd.write()
assert(vim.fn.filereadable(quickfile_path) == 1, "quickfile did not write the file")
assert(vim.fn.isdirectory(quickfile_dir .. "/nested/deep") == 1, "quickfile did not create the directory")
vim.fn.delete(quickfile_dir, "rf")

-- The picker must search the directory it is given, not the cwd.
local picker = require("nazovim.search.picker")
local picker_dir = vim.fn.tempname()
vim.fn.mkdir(picker_dir .. "/sub", "p")
vim.fn.writefile({ "needle-in-sub" }, picker_dir .. "/sub/hit.txt")
local picker_items
local original_input, original_select = vim.ui.input, vim.ui.select
vim.ui.input = function(_, on_confirm)
	on_confirm("needle-in-sub")
end
vim.ui.select = function(items, _, on_choice)
	picker_items = items
	on_choice(nil)
end
picker.grep(picker_dir)
local picker_done = vim.wait(10000, function()
	return picker_items ~= nil
end, 50)
vim.ui.input, vim.ui.select = original_input, original_select
assert(picker_done, "picker.grep produced no results")
assert(#picker_items == 1, "picker.grep should only report the given directory")
assert(picker_items[1].label:find("sub/hit.txt", 1, true), "picker.grep ignored its directory")
vim.fn.delete(picker_dir, "rf")

print(
	"features: terminal, filename overlays, mode colors, zen, statuscolumn, quickfile, dashboard, codex, claudecode, opencode, completion, lsp, git, icons, treesitter, ai_ask, dap, picker and commands passed"
)
vim.cmd("qall!")
