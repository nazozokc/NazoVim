vim.opt.rtp:prepend("apps/nvim")
vim.g.mapleader = " "
vim.o.swapfile = false
local api = vim.api
assert(vim.fn.executable("rg") == 1, "builtin tests require ripgrep (rg); run with nix develop --command nvim")
local function marks(name, buf)
	return api.nvim_buf_get_extmarks(buf or 0, api.nvim_create_namespace(name), 0, -1, { details = true })
end
local function equal(actual, expected)
	assert(vim.deep_equal(actual, expected), vim.inspect(actual) .. " != " .. vim.inspect(expected))
end
local temp = vim.fn.tempname()
vim.fn.mkdir(temp, "p")

-- Template selection, filenames containing spaces, literal substitutions, and overwrite safety.
local template = require("nazovim.template")
vim.g.nazovim_template_dir = vim.fn.getcwd() .. "/template"
vim.cmd.edit(vim.fn.fnameescape(temp .. "/my file.lua"))
template.insert("lua/module.lua")
assert(api.nvim_buf_get_lines(0, 0, 1, false)[1] == "-- my file.lua")
assert(api.nvim_buf_get_name(0) == temp .. "/my file.lua")
local expanded, cursor =
	template.expand({ "{{_file_name_}}", "x{{_cursor_}}y {{_author_}}", "{{_unknown_}}" }, "a%b.lua")
equal(expanded, { "a%b", "xy nazozokc", "{{_unknown_}}" })
equal(cursor, { 2, 1 })
assert(not pcall(template.insert, "../missing.lua"))
template.project("minimal", temp .. "/project")
assert(vim.fn.filereadable(temp .. "/project/gitignore") == 1)
local before = vim.fn.readfile(temp .. "/project/gitignore")
assert(not pcall(template.project, "minimal", temp .. "/project"))
equal(vim.fn.readfile(temp .. "/project/gitignore"), before)

-- Bounded color rendering, named colors, rgb/hsl, and local CSS variables.
local colors = require("nazovim.colors")
equal(colors.parse("#abc"), 0xaabbcc)
equal(colors.parse("#112233aa"), 0x112233)
equal(colors.parse("rgb(255 0 128 / 50%)"), 0xff0080)
equal(colors.parse("hsl(120, 100%, 50%)"), 0x00ff00)
equal(colors.parse("green"), 0x008000)
equal(colors.parse("#12345"), nil)
equal(colors.parse("rgb(nope)"), nil)
vim.cmd.enew({ bang = true })
api.nvim_buf_set_lines(
	0,
	0,
	-1,
	false,
	{ ":root { --accent: #123456; }", "a { color: var(--accent); background: hsl(120, 100%, 50%); }" }
)
colors.setup()
assert(#marks("NazoColors") >= 3)
api.nvim_buf_set_lines(0, 0, -1, false, { "nothing here" })
api.nvim_exec_autocmds("TextChanged", {})
assert(vim.wait(300, function()
	return #marks("NazoColors") == 0
end))

-- TODOs must not match identifier substrings or quoted strings without a parser.
local todo = require("nazovim.todo")
equal(#todo.matches("TODO: yes FIXME: yes NOTTODO: no TODO_without_colon"), 2)
vim.bo.filetype = "lua"
vim.bo.commentstring = "-- %s"
api.nvim_buf_set_lines(
	0,
	0,
	-1,
	false,
	{ "-- TODO: first", 'local s = "TODO: not a comment"', 'local s = "x" -- FIXME: actual comment' }
)
todo.setup()
assert(#marks("NazoTodo") == 2, vim.inspect(marks("NazoTodo")))
local cwd = vim.fn.getcwd()
vim.fn.writefile({ "-- TODO: project task" }, temp .. "/task.lua")
vim.cmd.cd(temp)
todo.search(false)
assert(vim.wait(3000, function()
	return #vim.fn.getqflist() > 0
end))
equal(vim.fn.getqflist()[1].lnum, 1)
vim.cmd.cclose()
vim.cmd.cd(cwd)

-- Native diagnostic config must cooperate with the standard enable/disable lifecycle.
require("nazovim.lsp.diagnostics").setup()
equal(vim.diagnostic.config().virtual_lines.current_line, true)
local diagnostic_ns = api.nvim_create_namespace("builtin-test-diagnostics")
vim.diagnostic.set(diagnostic_ns, 0, { { lnum = 0, col = 0, message = "test error", severity = 1 } })
vim.diagnostic.enable(false)
assert(not vim.diagnostic.is_enabled())
vim.diagnostic.enable(true)
assert(vim.diagnostic.is_enabled())

-- Statusline must escape '%' in external metadata and render without synchronous I/O.
local statusline = require("nazovim.statusline")
statusline.setup()
vim.b.gitsigns_head = "feature%branch"
local status = statusline.render()
assert(status:find("feature%%branch", 1, true))
local rendered = api.nvim_eval_statusline(status, { winid = api.nvim_get_current_win() })
assert(rendered.str:find("feature%branch", 1, true))
assert(rendered.str:find("E1", 1, true))
vim.diagnostic.reset(diagnostic_ns)

-- Search counts and mappings preserve the search register; nohlsearch clears the overlay.
vim.o.hlsearch = true
api.nvim_buf_set_lines(0, 0, -1, false, { "word word", "word" })
vim.fn.setreg("/", "word")
api.nvim_win_set_cursor(0, { 1, 0 })
vim.cmd("normal! n")
local search = require("nazovim.search")
search.setup()
search.update()
assert(#marks("NazoSearch") == 1)
equal(vim.fn.getreg("/"), "word")
vim.cmd.nohlsearch()
search.update()
assert(#marks("NazoSearch") == 0)

-- A single scrollbar survives scrolling/resizing without spawning more floats.
local scrollbar = require("nazovim.ui.scrollbar")
local layout = scrollbar.layout(100, 1, 20, 10, { { lnum = 50, severity = 2 }, { lnum = 50, severity = 1 } })
equal(layout[6].hl, "DiagnosticError")
local lines = {}
for i = 1, 200 do
	lines[i] = "line " .. i
end
api.nvim_buf_set_lines(0, 0, -1, false, lines)
local main = api.nvim_get_current_win()
scrollbar.setup()
local wins = #api.nvim_tabpage_list_wins(0)
for i = 1, 10 do
	api.nvim_win_set_cursor(main, { i * 10, 0 })
	scrollbar.update()
end
equal(#api.nvim_tabpage_list_wins(0), wins)
vim.cmd.vsplit()
scrollbar.update()
equal(#api.nvim_tabpage_list_wins(0), wins + 1)
vim.cmd.close()
api.nvim_buf_set_lines(0, 0, -1, false, { "short" })
scrollbar.update()
equal(#api.nvim_tabpage_list_wins(0), 1)

-- Progress tokens from different clients must not collide or leak windows on completion.
local progress = require("nazovim.lsp.progress")
progress.setup()
local function event(id, kind)
	progress.handle({ client_id = id, params = { token = "same", value = { kind = kind, title = "Indexing" } } })
end
event(9001, "begin")
event(9002, "begin")
equal(#api.nvim_tabpage_list_wins(0), 2)
local progress_win
for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
	if win ~= main then
		progress_win = win
	end
end
equal(api.nvim_buf_line_count(api.nvim_win_get_buf(progress_win)), 2)
event(9001, "end")
event(9002, "end")
assert(vim.wait(2600, function()
	return #api.nvim_tabpage_list_wins(0) == 1
end))

-- Mock only the server boundary: verify UTF-16 conversion, cancellation, and stale replies.
local refs = require("nazovim.lsp.references")
api.nvim_buf_set_lines(0, 0, -1, false, { "é name name" })
api.nvim_win_set_cursor(0, { 1, 3 })
local callbacks, cancelled = {}, 0
local client = {
	offset_encoding = "utf-16",
	request = function(_, _, _, callback)
		callbacks[#callbacks + 1] = callback
		return true, #callbacks
	end,
	cancel_request = function()
		cancelled = cancelled + 1
	end,
}
local original_clients = vim.lsp.get_clients
vim.lsp.get_clients = function()
	return { client }
end
local result = { { range = { start = { line = 0, character = 2 }, ["end"] = { line = 0, character = 6 } }, kind = 2 } }
refs.update()
api.nvim_win_set_cursor(0, { 1, 8 })
callbacks[1](nil, result)
equal(#marks("NazoReferences"), 0)
refs.update()
callbacks[2](nil, result)
equal(marks("NazoReferences")[1][3], 3)
assert(cancelled > 0)
api.nvim_buf_set_lines(0, 0, -1, false, { "changed" })
callbacks[2](nil, result)
refs.setup()
api.nvim_buf_set_lines(0, 0, -1, false, { "é name name" })
api.nvim_win_set_cursor(0, { 1, 3 })
refs.update()
callbacks[#callbacks](nil, result)
vim.fn.feedkeys(api.nvim_replace_termcodes("d<M-i>", true, false, true), "xt")
equal(api.nvim_get_current_line(), "é  name")
vim.lsp.get_clients = original_clients

-- Spec discovery must exclude every removed plugin.
vim.opt.rtp:prepend("apps/nazoplug")
local specs = assert(
	require("nazoplug.spec").collect(
		{ import = "plugins" },
		{ pack_dir = temp .. "/plugins", defaults = { lazy = true } }
	)
)
local removed = {
	"lualine.nvim",
	"nvim-hlslens",
	"template.nvim",
	"tiny-inline-diagnostic.nvim",
	"fidget.nvim",
	"todo-comments.nvim",
	"vim-illuminate",
	"nvim-highlight-colors",
	"satellite.nvim",
	"nvim-scrollbar",
	"nvim-autopairs",
	"mini.ai",
	"mini.surround",
	"mini.comment",
	"mini.indentscope",
	"which-key.nvim",
	"dial.nvim",
	"nvim-spider",
	"marks.nvim",
	"spellsitter.nvim",
	"barbar.nvim",
	"hlchunk.nvim",
	"indent-blankline.nvim",
	"nvim-ufo",
	"octo.nvim",
	"telescope.nvim",
	"neo-tree.nvim",
	"yazi.nvim",
	"snacks.nvim",
	"codex.nvim",
	"claudecode.nvim",
	"opencode.nvim",
	"nvim-cmp",
	"cmp-buffer",
	"cmp-calc",
	"cmp-nvim-lsp",
	"cmp-path",
	"copilot-cmp",
	"mason.nvim",
	"mason-lspconfig.nvim",
	"nvim-lspconfig",
	"zls",
	"lazydev.nvim",
	"vim-fugitive",
	"nvim-web-devicons",
	"nvim-treesitter",
	"typescript-tools.nvim",
	"rustaceanvim",
	"nvim-java",
	"spring-boot.nvim",
	"avante.nvim",
	"nui.nvim",
	"mega.cmdparse",
	"mega.logging",
	"nvim-dap",
	"nvim-dap-vscode-js",
	"vscode-js-debug",
	"CopilotChat.nvim",
	"copilot.lua",
	"plenary.nvim",
}
for _, spec in ipairs(specs) do
	assert(not vim.tbl_contains(removed, spec.name), spec.name)
end

vim.fn.delete(temp, "rf")
print(
	"builtins: templates, colors, TODOs, diagnostics, statusline, search, scrollbar, progress and stale LSP replies passed"
)
vim.cmd("qall!")
