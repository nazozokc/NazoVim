local M = {}

local palette = {
	background = "#142024",
	foreground = "#d8e3df",
	muted = "#8a9d9d",
	line = "#203238",
	selection = "#29434a",
	border = "#49636a",
	red = "#ed8278",
	orange = "#e7a66e",
	yellow = "#e2c77b",
	green = "#a4cb91",
	cyan = "#7bc8bd",
	blue = "#88b8dd",
	purple = "#bea4df",
	pink = "#dfa7b4",
	white = "#eef3eb",
}

local function set(name, value)
	vim.api.nvim_set_hl(0, name, value)
end

function M.apply()
	vim.opt.background = "dark"
	local p = palette
	for _, name in ipairs({ "Normal", "NormalNC", "SignColumn", "FoldColumn", "EndOfBuffer", "LineNr" }) do
		set(name, { fg = p.muted, bg = "NONE" })
	end
	set("Normal", { fg = p.foreground, bg = "NONE" })
	set("NormalNC", { fg = p.foreground, bg = "NONE" })
	set("Cursor", { fg = p.background, bg = p.cyan })
	set("CursorLine", { bg = p.line })
	set("CursorLineNr", { fg = p.yellow, bold = true, bg = "NONE" })
	set("ColorColumn", { bg = p.line })
	set("Visual", { bg = p.selection })
	set("Search", { fg = p.background, bg = p.yellow })
	set("IncSearch", { fg = p.background, bg = p.orange, bold = true })
	set("CurSearch", { fg = p.background, bg = p.orange, bold = true })
	set("MatchParen", { fg = p.white, bg = p.selection, bold = true, underline = true })
	set("Whitespace", { fg = p.border })
	set("NonText", { fg = p.border })
	set("WinSeparator", { fg = p.border, bg = "NONE" })
	set("VertSplit", { fg = p.border, bg = "NONE" })
	set("Folded", { fg = p.muted, bg = p.line, italic = true })
	set("Directory", { fg = p.cyan, bold = true })
	set("Title", { fg = p.cyan, bold = true })
	set("Question", { fg = p.green, bold = true })
	set("MoreMsg", { fg = p.green })
	set("WarningMsg", { fg = p.yellow })
	set("ErrorMsg", { fg = p.red, bold = true })
	set("Pmenu", { fg = p.foreground, bg = p.background })
	set("PmenuSel", { fg = p.white, bg = p.selection, bold = true })
	set("PmenuSbar", { bg = p.line })
	set("PmenuThumb", { bg = p.cyan })
	set("FloatBorder", { fg = p.border, bg = "NONE" })
	set("NormalFloat", { fg = p.foreground, bg = "NONE" })
	set("FloatTitle", { fg = p.cyan, bg = "NONE", bold = true })
	set("TabLine", { fg = p.muted, bg = p.line })
	set("TabLineSel", { fg = p.white, bg = p.selection, bold = true })
	set("TabLineFill", { fg = p.muted, bg = "NONE" })
	set("StatusLine", { fg = p.foreground, bg = p.line })
	set("StatusLineNC", { fg = p.muted, bg = "NONE" })
	set("Comment", { fg = p.muted, italic = true })
	set("Constant", { fg = p.purple })
	set("String", { fg = p.green })
	set("Character", { fg = p.green })
	set("Number", { fg = p.purple })
	set("Boolean", { fg = p.purple, bold = true })
	set("Float", { fg = p.purple })
	set("Identifier", { fg = p.blue })
	set("Function", { fg = p.cyan })
	set("Statement", { fg = p.pink })
	set("Conditional", { fg = p.pink })
	set("Repeat", { fg = p.pink })
	set("Operator", { fg = p.muted })
	set("Keyword", { fg = p.pink })
	set("Exception", { fg = p.red })
	set("PreProc", { fg = p.orange })
	set("Include", { fg = p.orange })
	set("Define", { fg = p.orange })
	set("Macro", { fg = p.orange })
	set("Type", { fg = p.yellow })
	set("StorageClass", { fg = p.pink })
	set("Structure", { fg = p.yellow })
	set("Typedef", { fg = p.yellow })
	set("Special", { fg = p.cyan })
	set("SpecialChar", { fg = p.orange })
	set("Tag", { fg = p.red })
	set("Delimiter", { fg = p.muted })
	set("SpecialComment", { fg = p.yellow, italic = true })
	set("Underlined", { fg = p.blue, underline = true })
	set("Todo", { fg = p.background, bg = p.yellow, bold = true })
	set("Error", { fg = p.red, undercurl = true })
	set("DiagnosticError", { fg = p.red })
	set("DiagnosticWarn", { fg = p.yellow })
	set("DiagnosticInfo", { fg = p.blue })
	set("DiagnosticHint", { fg = p.cyan })
	set("DiagnosticOk", { fg = p.green })
	set("DiffAdd", { fg = p.green, bg = "#1d302a" })
	set("DiffChange", { fg = p.yellow, bg = "#302d20" })
	set("DiffDelete", { fg = p.red, bg = "#352522" })
	set("DiffText", { fg = p.white, bg = p.selection, bold = true })
	set("Added", { fg = p.green })
	set("Changed", { fg = p.yellow })
	set("Removed", { fg = p.red })
	set("@comment", { link = "Comment" })
	set("@variable", { fg = p.foreground })
	set("@variable.builtin", { fg = p.orange })
	set("@constant", { fg = p.purple })
	set("@constant.builtin", { fg = p.orange })
	set("@string", { fg = p.green })
	set("@string.escape", { fg = p.orange, bold = true })
	set("@character", { fg = p.green })
	set("@number", { fg = p.purple })
	set("@boolean", { fg = p.purple, bold = true })
	set("@function", { fg = p.cyan })
	set("@function.call", { fg = p.cyan })
	set("@function.builtin", { fg = p.blue })
	set("@method", { fg = p.cyan })
	set("@constructor", { fg = p.yellow })
	set("@parameter", { fg = p.orange })
	set("@keyword", { fg = p.pink })
	set("@keyword.function", { fg = p.pink, italic = true })
	set("@keyword.return", { fg = p.pink, bold = true })
	set("@operator", { fg = p.muted })
	set("@type", { fg = p.yellow })
	set("@type.builtin", { fg = p.yellow, italic = true })
	set("@property", { fg = p.blue })
	set("@field", { fg = p.blue })
	set("@attribute", { fg = p.orange })
	set("@tag", { fg = p.red })
	set("@tag.attribute", { fg = p.blue })
	set("@punctuation.bracket", { fg = p.muted })
	set("@punctuation.delimiter", { fg = p.muted })
	set("@markup.heading", { fg = p.cyan, bold = true })
	set("@markup.strong", { fg = p.white, bold = true })
	set("@markup.italic", { fg = p.purple, italic = true })
	set("@markup.link", { fg = p.blue, underline = true })
	set("@markup.raw", { fg = p.green })
	set("@markup.list", { fg = p.orange })
	vim.g.colors_name = "nazovim"
end

function M.setup()
	vim.cmd.colorscheme("nazovim")
end

return M
