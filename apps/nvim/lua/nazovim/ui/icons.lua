-- The icon glyphs, names, and brand colors below are derived from
-- nvim-web-devicons <https://github.com/nvim-tree/nvim-web-devicons>.
-- Copyright (c) 2023 nvim-tree. Licensed under the MIT License.
-- The full license text is in THIRD_PARTY_LICENSES.md at the repository root.
local M = {}

local default_icon = "󰈔"
local default_highlight = "NazoIconDefault"

---Icon table keyed by lowercase extension.
local by_extension = {
	lua = { icon = "󰢱", name = "Lua", color = "#51a0cf" },
	vim = { icon = "", name = "Vim", color = "#019833" },
	js = { icon = "", name = "JavaScript", color = "#cbcb41" },
	mjs = { icon = "", name = "JavaScript", color = "#cbcb41" },
	cjs = { icon = "", name = "JavaScript", color = "#cbcb41" },
	jsx = { icon = "", name = "React", color = "#61dafb" },
	ts = { icon = "", name = "TypeScript", color = "#519aba" },
	tsx = { icon = "", name = "React", color = "#61dafb" },
	json = { icon = "", name = "Json", color = "#cbcb41" },
	jsonc = { icon = "", name = "Json", color = "#cbcb41" },
	md = { icon = "", name = "Markdown", color = "#519aba" },
	html = { icon = "", name = "Html", color = "#e34c26" },
	css = { icon = "", name = "Css", color = "#42a5f5" },
	scss = { icon = "", name = "Sass", color = "#f55385" },
	py = { icon = "", name = "Python", color = "#ffbc03" },
	rs = { icon = "", name = "Rust", color = "#dea584" },
	go = { icon = "", name = "Go", color = "#519aba" },
	java = { icon = "", name = "Java", color = "#cc3e44" },
	kt = { icon = "", name = "Kotlin", color = "#7f52ff" },
	c = { icon = "", name = "C", color = "#599eff" },
	h = { icon = "", name = "CHeader", color = "#a074c4" },
	cpp = { icon = "", name = "Cpp", color = "#519aba" },
	hpp = { icon = "", name = "CppHeader", color = "#a074c4" },
	rb = { icon = "", name = "Ruby", color = "#cc3e44" },
	php = { icon = "", name = "Php", color = "#a074c4" },
	sh = { icon = "", name = "Shell", color = "#4d5a5e" },
	bash = { icon = "", name = "Shell", color = "#4d5a5e" },
	zsh = { icon = "", name = "Shell", color = "#4d5a5e" },
	fish = { icon = "", name = "Shell", color = "#4d5a5e" },
	nix = { icon = "", name = "Nix", color = "#7eb3e6" },
	yml = { icon = "", name = "Yaml", color = "#e37933" },
	yaml = { icon = "", name = "Yaml", color = "#e37933" },
	toml = { icon = "", name = "Toml", color = "#9c4221" },
	txt = { icon = "󰈙", name = "Text", color = "#89e051" },
	svg = { icon = "󰜡", name = "Svg", color = "#ffb13b" },
	png = { icon = "󰸭", name = "Image", color = "#a074c4" },
	jpg = { icon = "󰸭", name = "Image", color = "#a074c4" },
	jpeg = { icon = "󰸭", name = "Image", color = "#a074c4" },
	gif = { icon = "󰸭", name = "Image", color = "#a074c4" },
	pdf = { icon = "󰈦", name = "Pdf", color = "#cc3e44" },
	zip = { icon = "󰗄", name = "Zip", color = "#eca517" },
	mp3 = { icon = "󰎆", name = "Audio", color = "#00afff" },
	mp4 = { icon = "󰈫", name = "Video", color = "#fd971f" },
	lock = { icon = "󰌾", name = "Lock", color = "#bbbbbb" },
	gitignore = { icon = "", name = "GitIgnore", color = "#f14e32" },
}

---Icon table keyed by lowercase filename.
local by_filename = {
	["makefile"] = { icon = "", name = "Makefile", color = "#6d8086" },
	["dockerfile"] = { icon = "󰡨", name = "Dockerfile", color = "#458ee6" },
	["license"] = { icon = "", name = "License", color = "#d0bf41" },
	["readme.md"] = { icon = "󰂺", name = "Readme", color = "#519aba" },
	[".gitignore"] = { icon = "", name = "GitIgnore", color = "#f14e32" },
	[".gitattributes"] = { icon = "", name = "GitIgnore", color = "#f14e32" },
	["flake.nix"] = { icon = "", name = "Nix", color = "#7eb3e6" },
	["flake.lock"] = { icon = "", name = "Nix", color = "#7eb3e6" },
	["package.json"] = { icon = "", name = "NodePackage", color = "#cbcb41" },
	["tsconfig.json"] = { icon = "", name = "TypeScript", color = "#519aba" },
	[".luarc.json"] = { icon = "󰢱", name = "Lua", color = "#51a0cf" },
	["stylua.toml"] = { icon = "󰢱", name = "Lua", color = "#51a0cf" },
}

---Icon table keyed by filetype.
local by_filetype = {
	lua = "lua",
	vim = "vim",
	javascript = "js",
	javascriptreact = "jsx",
	typescript = "ts",
	typescriptreact = "tsx",
	json = "json",
	jsonc = "jsonc",
	markdown = "md",
	html = "html",
	css = "css",
	scss = "scss",
	python = "py",
	rust = "rs",
	go = "go",
	java = "java",
	kotlin = "kt",
	c = "c",
	cpp = "cpp",
	ruby = "rb",
	php = "php",
	sh = "sh",
	bash = "bash",
	zsh = "zsh",
	fish = "fish",
	nix = "nix",
	yaml = "yaml",
	toml = "toml",
	text = "txt",
	gitcommit = "gitignore",
	gitconfig = "gitignore",
}

local defined = {}

local function highlight_name(entry)
	return "NazoIcon" .. (entry.name or "Default")
end

local function define_highlight(entry)
	local group = highlight_name(entry)
	if defined[group] then
		return group
	end
	defined[group] = true
	vim.api.nvim_set_hl(0, group, { fg = entry.color or "#bbbbbb" })
	return group
end

local function resolve(entry)
	if not entry then
		return nil
	end
	return entry.icon, define_highlight(entry)
end

local function extension_of(name)
	local base = vim.fn.fnamemodify(name, ":t")
	local extension = base:match("%.([^.]+)$")
	return extension and extension:lower() or nil
end

---Return the icon and highlight group for a file name.
---@param name string
---@param extension? string
---@param _opts? table
---@return string, string
function M.get_icon(name, extension, _opts)
	name = name or ""
	local base = vim.fn.fnamemodify(name, ":t"):lower()
	local entry = by_filename[base]
	if not entry then
		entry = by_extension[(extension or extension_of(base) or ""):lower()]
	end
	local icon, group = resolve(entry)
	if not icon then
		return default_icon, default_highlight
	end
	return icon, group
end

---Return the icon and highlight group for a filetype.
---@param filetype string
---@param _opts? table
---@return string, string
function M.get_icon_by_filetype(filetype, _opts)
	local extension = by_filetype[(filetype or ""):lower()]
	if not extension then
		return default_icon, default_highlight
	end
	local icon, group = resolve(by_extension[extension])
	if not icon then
		return default_icon, default_highlight
	end
	return icon, group
end

---Return the icons keyed by extension, in the devicons shape.
---@return table<string, table>
function M.get_icons_by_extension()
	local result = {}
	for extension, entry in pairs(by_extension) do
		result[extension] = { icon = entry.icon, name = entry.name, cterm_color = "0", color = entry.color }
	end
	return result
end

---Return the icons keyed by filename, in the devicons shape.
---@return table<string, table>
function M.get_icons_by_filename()
	local result = {}
	for filename, entry in pairs(by_filename) do
		result[filename] = { icon = entry.icon, name = entry.name, cterm_color = "0", color = entry.color }
	end
	return result
end

---Return every known icon, in the devicons shape.
---@return table<string, table>
function M.get_icons()
	local result = M.get_icons_by_extension()
	for key, value in pairs(M.get_icons_by_filename()) do
		result[key] = value
	end
	return result
end

---Return the configured default icon and highlight group.
---@return string, string
function M.get_default_icon()
	return default_icon, default_highlight
end

---Override the icon for an extension or filetype.
---@param spec table { name?, extension?, filetype?, icon, color? }
function M.set_icon(spec)
	if type(spec) ~= "table" or type(spec.icon) ~= "string" then
		return
	end
	local entry = { icon = spec.icon, name = spec.name or "Custom", color = spec.color }
	if spec.extension then
		by_extension[spec.extension:lower()] = entry
	elseif spec.filetype then
		by_filetype[spec.filetype:lower()] = spec.extension or spec.filetype:lower()
	end
end

---Replace the fallback icon.
---@param icon string
---@param color? string
function M.set_default_icon(icon, color)
	if type(icon) ~= "string" or icon == "" then
		return
	end
	default_icon = icon
	default_highlight = "NazoIconCustomDefault"
	defined[default_highlight] = nil
	define_highlight({ name = "CustomDefault", color = color })
end

---Icons are always available, so this matches the devicons contract.
---@return boolean
function M.has_loaded()
	return true
end

---Define the highlight groups up front so redraws never create them.
function M.setup()
	vim.api.nvim_set_hl(0, default_highlight, { fg = "#bbbbbb" })
	defined[default_highlight] = true
	for _, entry in pairs(by_extension) do
		define_highlight(entry)
	end
	for _, entry in pairs(by_filename) do
		define_highlight(entry)
	end
end

return M
