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
vim.cmd.startinsert()
vim.fn.feedkeys("(", "xt")
equal(api.nvim_get_current_line(), "()")
equal(api.nvim_win_get_cursor(0)[2], 1)
vim.fn.feedkeys(")", "xt")
equal(api.nvim_get_current_line(), "()")
equal(api.nvim_win_get_cursor(0)[2], 2)
vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<BS>", true, false, true), "xt")
equal(api.nvim_get_current_line(), "")
vim.fn.feedkeys("x", "xt")
vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), "xt")
vim.cmd.stopinsert()
equal(api.nvim_get_current_line(), "")
assert(#api.nvim_buf_get_lines(0, 0, -1, false) >= 1)

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

-- Indent guide scope.
local indent = require("nazovim.indent")
equal(indent.scope_col("    value", 2), 2)
equal(indent.scope_col("  value", 2), nil)
vim.cmd.enew({ bang = true })
api.nvim_buf_set_lines(0, 0, -1, false, { "    value" })
api.nvim_win_set_cursor(0, { 1, 4 })
indent.setup()
indent.update()
equal(#extmarks("NazoIndent") , 1)

-- Dial: integers, booleans, constants, floats, and line updates.
local dial = require("nazovim.dial")
equal(dial.find("let x = 41", 9).text, "41")
equal(dial.next(dial.find("let x = 41", 9), 1), "42")
equal(dial.next(dial.find("enabled = true", 12), 1), "false")
equal(dial.next(dial.find("const name", 2), 1), "var")
equal(dial.next(dial.find("0x1f", 2), 1), "0x20")
equal(dial.next(dial.find("3.14", 2), 1), "3.15")
equal(dial.increment_line("a 1 b 2", 1), "a 2 b 3")

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

-- Marks: signs and quickfix entries.
local marks = require("nazovim.marks")
vim.cmd.enew({ bang = true })
api.nvim_buf_set_lines(0, 0, -1, false, { "first", "second" })
vim.fn.setpos("'a", { 0, 2, 1, 0 })
marks.setup()
marks.update(0)
local placed = vim.fn.sign_getplaced(0, { group = "nazo-marks" })[1].signs
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
assert(type(folding.foldexpr(1)) == "number")
api.nvim_buf_set_lines(0, 0, -1, false, { "function x()", "  return 1", "end" })
api.nvim_win_set_cursor(0, { 1, 0 })
vim.cmd("normal! zf2j")
local foldtext = folding.foldtext()
assert(foldtext:find("function x()", 1, true), foldtext)

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

print("replacements: pairs, surround, indent, dial, motion, marks, spell, tabline, folding and which-key passed")
vim.cmd("qall!")
