vim.opt.rtp:prepend("apps/nvim")
vim.g.mapleader = " "
vim.o.swapfile = false
local api = vim.api

local function equal(actual, expected)
	assert(vim.deep_equal(actual, expected), vim.inspect(actual) .. " != " .. vim.inspect(expected))
end

local function extmarks(namespace, buf)
	return api.nvim_buf_get_extmarks(buf or 0, api.nvim_create_namespace(namespace), 0, -1, { details = true })
end

-- Auto pairs: open, skip, delete, and expand.
local pairs = require("nazovim.pairs")
vim.cmd.enew({ bang = true })
pairs.attach(0)
assert(vim.fn.maparg("(", "i", false, true).callback ~= nil)
api.nvim_buf_set_lines(0, 0, -1, false, { "" })
api.nvim_win_set_cursor(0, { 1, 0 })
local opened = pairs.open("(")
assert(opened:sub(1, 2) == "()", vim.inspect(opened))
equal(pairs.open(")"), ")")
api.nvim_buf_set_lines(0, 0, -1, false, { "()" })
api.nvim_win_set_cursor(0, { 1, 1 })
assert(#pairs.close(")") > 1)
assert(#pairs.backspace() > 1)
api.nvim_buf_set_lines(0, 0, -1, false, { "()" })
api.nvim_win_set_cursor(0, { 1, 1 })
vim.bo.expandtab = true
vim.bo.shiftwidth = 2
pairs.enter()
equal(api.nvim_buf_get_lines(0, 0, -1, false), { "(", "  ", ")" })
equal(api.nvim_win_get_cursor(0)[1], 2)

-- Special buffers must not receive insert-mode pair mappings.
local scratch = api.nvim_create_buf(false, true)
pairs.attach(scratch)
equal(#api.nvim_buf_get_keymap(scratch, "i"), 0)
api.nvim_buf_delete(scratch, { force = true })

-- Surround: add, find, replace, delete.
local surround = require("nazovim.surround")
vim.cmd.enew({ bang = true })
api.nvim_buf_set_lines(0, 0, -1, false, { "local value = foo" })
surround.add(0, 1, 14, 1, 17, "(", ")")
equal(api.nvim_get_current_line(), "local value = (foo)")
local found = surround.find(0, 1, 15, "(", ")")
equal(found, { srow = 1, scol = 14, erow = 1, ecol = 18 })
assert(surround.replace(0, 1, 15, "(", ")", "[", "]"))
equal(api.nvim_get_current_line(), "local value = [foo]")
assert(surround.delete(0, 1, 15, "[", "]"))
equal(api.nvim_get_current_line(), "local value = foo")
api.nvim_buf_set_lines(0, 0, -1, false, { 'local s = "text"' })
local quote = surround.find(0, 1, 12, '"', '"')
assert(quote and quote.scol == 10 and quote.ecol == 15)
vim.cmd.enew({ bang = true })
api.nvim_buf_set_lines(0, 0, -1, false, { "(foo)" })
api.nvim_win_set_cursor(0, { 1, 2 })
assert(surround.delete(0, 1, 2, "(", ")"))
equal(api.nvim_get_current_line(), "foo")
equal(api.nvim_win_get_cursor(0), { 1, 1 })

-- Indent guide scope.
local indent = require("nazovim.indent")
equal(indent.scope_col("    value", 2), 2)
equal(indent.scope_col("  value", 2), 0)
vim.cmd.enew({ bang = true })
api.nvim_buf_set_lines(0, 0, -1, false, { "    value" })
api.nvim_win_set_cursor(0, { 1, 4 })
vim.bo.shiftwidth = 2
vim.bo.tabstop = 2
indent.setup()
indent.update()
equal(#extmarks("NazoIndent"), 1)
api.nvim_buf_set_lines(0, 0, -1, false, { "function x()", "  if y then", "    a", "    b", "  end", "end" })
api.nvim_win_set_cursor(0, { 3, 4 })
local top, bottom = indent.block(0, 3, 2)
equal({ top, bottom }, { 3, 4 })
indent.update()
equal(#extmarks("NazoIndent"), 2)

-- Dial: integers, booleans, constants, floats, and line updates.
local dial = require("nazovim.dial")
equal(dial.find("let x = 41", 9).text, "41")
equal(dial.next(dial.find("let x = 41", 9), 1), "42")
equal(dial.next(dial.find("enabled = true", 12), 1), "false")
equal(dial.next(dial.find("const name", 2), 1), "var")
equal(dial.next(dial.find("0x1f", 2), 1), "0x20")
equal(dial.next(dial.find("3.14", 2), 1), "3.15")
equal(dial.increment_line("a 1 b 2", 1), "a 2 b 3")
equal(dial.tokens("foo-1")[1].text, "1")
equal(dial.increment_line("foo-1", 1), "foo-2")
equal(dial.increment_line("a 1 b 2", 1, 4, 6), "a 1 b 3")
vim.cmd.enew({ bang = true })
api.nvim_buf_set_lines(0, 0, -1, false, { "x = 41" })
api.nvim_win_set_cursor(0, { 1, 4 })
dial.increment(1)
equal(api.nvim_get_current_line(), "x = 42")

-- Visual ranges come from the anchor mark, not the unset '< / '> marks.
vim.cmd.enew({ bang = true })
api.nvim_buf_set_lines(0, 0, -1, false, { "a 1 b 2" })
vim.cmd("normal! 0v$")
local srow, scol, erow, ecol = require("nazovim.ui").visual_range()
vim.cmd("normal! \27")
equal({ srow, scol, erow, ecol }, { 1, 0, 1, 6 })

-- Spider motions split camelCase and snake_case.
local motion = require("nazovim.motion")
local texts = {}
for _, token in ipairs(motion.tokens("fooBar_baz qux")) do
	texts[#texts + 1] = token.text
end
equal(texts, { "foo", "Bar", "baz", "qux" })
vim.cmd.enew({ bang = true })
api.nvim_buf_set_lines(0, 0, -1, false, { "fooBar_baz qux" })
api.nvim_win_set_cursor(0, { 1, 0 })
motion.move("w")
equal(api.nvim_win_get_cursor(0), { 1, 3 })
motion.move("e")
equal(api.nvim_win_get_cursor(0), { 1, 5 })
motion.move("b")
equal(api.nvim_win_get_cursor(0), { 1, 3 })

-- Character-find motions span lines and repeat/reverse the last search.
vim.cmd.enew({ bang = true })
api.nvim_buf_set_lines(0, 0, -1, false, { "ax", "bxa", "xa" })
api.nvim_win_set_cursor(0, { 1, 0 })
require("nazovim.motion").setup()
vim.api.nvim_feedkeys("fx", "xt", false)
equal(api.nvim_win_get_cursor(0), { 1, 1 })
vim.api.nvim_feedkeys(";", "xt", false)
equal(api.nvim_win_get_cursor(0), { 2, 1 })
vim.api.nvim_feedkeys(",", "xt", false)
equal(api.nvim_win_get_cursor(0), { 1, 1 })
api.nvim_win_set_cursor(0, { 1, 0 })
vim.api.nvim_feedkeys("tx", "xt", false)
equal(api.nvim_win_get_cursor(0), { 1, 0 })
api.nvim_win_set_cursor(0, { 3, 2 })
vim.api.nvim_feedkeys("Fx", "xt", false)
equal(api.nvim_win_get_cursor(0), { 3, 0 })
vim.api.nvim_feedkeys(";", "xt", false)
equal(api.nvim_win_get_cursor(0), { 2, 1 })
api.nvim_win_set_cursor(0, { 3, 2 })
vim.api.nvim_feedkeys("Tx", "xt", false)
equal(api.nvim_win_get_cursor(0), { 3, 1 })
-- Marks: signs and quickfix entries.
local marks = require("nazovim.marks")
vim.cmd.enew({ bang = true })
api.nvim_buf_set_lines(0, 0, -1, false, { "first", "second" })
vim.fn.setpos("'a", { 0, 2, 1, 0 })
local mark_buffer = api.nvim_get_current_buf()
marks.setup()
marks.update(mark_buffer)
local placed = vim.fn.sign_getplaced(mark_buffer, { group = "nazo-marks" })[1].signs
assert(#placed == 1, vim.inspect(placed))
equal(placed[1].lnum, 2)

-- Spell checking only applies to prose filetypes.
local spell = require("nazovim.spell")
assert(spell.wanted("markdown"))
assert(not spell.wanted("lua"))
vim.bo.filetype = "markdown"
spell.setup()
spell.apply(0)
assert(vim.wo.spell)
vim.bo.filetype = "lua"
spell.apply(0)
assert(not vim.wo.spell)

-- `spell` is window-local: applying it must not leak into other windows.
vim.cmd.enew({ bang = true })
api.nvim_buf_set_lines(0, 0, -1, false, { "# title" })
vim.bo.filetype = "markdown"
local markdown_buf = api.nvim_get_current_buf()
vim.cmd.enew({ bang = true })
api.nvim_buf_set_lines(0, 0, -1, false, { "local x = 1" })
vim.bo.filetype = "lua"
vim.cmd("split")
local markdown_win = api.nvim_get_current_win()
api.nvim_win_set_buf(markdown_win, markdown_buf)
spell.apply(markdown_buf)
assert(vim.wo[markdown_win].spell)
for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
	if win ~= markdown_win then
		assert(not vim.wo[win].spell)
	end
end
vim.cmd("only")

-- Buffer tabline renders, clicks, and cycles.
local tabline = require("nazovim.tabline")
vim.cmd.enew({ bang = true })
vim.cmd.file("one.lua")
vim.cmd.enew({ bang = true })
vim.cmd.file("two.lua")
tabline.setup()
local rendered = tabline.render()
assert(rendered:find("one.lua", 1, true), rendered)
assert(rendered:find("two.lua", 1, true), rendered)
local first = vim.fn.bufnr("one.lua")
tabline.click(first)
equal(api.nvim_get_current_buf(), first)
tabline.next()
assert(api.nvim_get_current_buf() ~= first)

-- Folding uses Treesitter when possible and indentation otherwise.
local folding = require("nazovim.folding")
folding.setup()
assert(vim.o.foldexpr:find("nazovim.folding", 1, true))
assert(type(folding.foldexpr(1)) == "number" or type(folding.foldexpr(1)) == "string")
api.nvim_buf_set_lines(0, 0, -1, false, { "function x()", "  return 1", "end" })
api.nvim_win_set_cursor(0, { 1, 0 })
vim.wo.foldmethod = "manual"
vim.cmd("normal! zf2j")
local foldtext = vim.fn.foldtextresult(1)
assert(foldtext:find("function x()", 1, true), foldtext)
vim.wo.foldmethod = "expr"

-- Which-key lists and displays pending mappings.
local whichkey = require("nazovim.whichkey")
whichkey.setup()
vim.keymap.set("n", "<leader>zz", function() end, { desc = "Test mapping" })
local items = whichkey.items(" ", "n")
assert(#items > 0)
local lines = whichkey.render(items)
assert(#lines > 0)
whichkey.show(" ", "n")
assert(#api.nvim_tabpage_list_wins(0) == 2)
whichkey.hide()
equal(#api.nvim_tabpage_list_wins(0), 1)
vim.keymap.set("x", "<leader>zz", function() end, { desc = "Visual test mapping" })
assert(#whichkey.items(" ", "x") > 0)

print("replacements: pairs, surround, indent, dial, motion, marks, spell, tabline, folding and which-key passed")
vim.cmd("qall!")
