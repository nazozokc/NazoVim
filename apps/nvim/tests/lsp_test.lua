vim.opt.rtp:prepend("apps/nvim")
vim.g.mapleader = " "
vim.o.swapfile = false

local api = vim.api

local function equal(actual, expected, label)
	assert(vim.deep_equal(actual, expected), label .. ": " .. vim.inspect(actual) .. " != " .. vim.inspect(expected))
end

local lsp = require("nazovim.lsp")
lsp.setup()

-- Every configured server is complete enough to start.
for name, server in pairs(lsp.servers()) do
	assert(lsp.binary(server), name .. " has no executable")
	assert(
		type(server.cmd) == "table" or type(server.cmd) == "function",
		name .. " has no cmd"
	)
	assert(#server.filetypes > 0, name .. " has no filetypes")
	assert(vim.lsp.config[name] ~= nil, name .. " was not registered with vim.lsp.config")
end

-- Filetypes added in this change resolve to a server.
local filetypes = {
	css = "cssls",
	json = "jsonls",
	markdown = "marksman",
	toml = "taplo",
	yaml = "yamlls",
	sh = "bashls",
	go = "gopls",
	python = "pyright",
	html = "html",
	lua = "lua_ls",
	rust = "rust_analyzer",
}
for filetype, name in pairs(filetypes) do
	local server = lsp.servers()[name]
	assert(server, "lsp server is missing: " .. name)
	assert(vim.tbl_contains(server.filetypes, filetype), name .. " does not handle " .. filetype)
end

-- enabled() and missing() mirror PATH exactly and never overlap.
for _, name in ipairs(lsp.enabled()) do
	assert(vim.fn.executable(lsp.binary(lsp.servers()[name])) == 1, name .. " is enabled without an executable")
end
for _, name in ipairs(lsp.missing()) do
	assert(
		vim.fn.executable(lsp.binary(lsp.servers()[name])) == 0,
		name .. " is reported missing but its executable exists"
	)
end
equal(#lsp.enabled() + #lsp.missing(), vim.tbl_count(lsp.servers()), "enabled + missing covered every server")

-- Shared float styling is registered once on the wildcard config.
assert(type(vim.lsp.config["*"].handlers["textDocument/hover"]) == "function", "hover handler is missing")
assert(
	type(vim.lsp.config["*"].handlers["textDocument/signatureHelp"]) == "function",
	"signature help handler is missing"
)

-- Capability overrides are declarative and only touch their own server.
local override = lsp.overrides().ts_ls
assert(override, "ts_ls override is missing")
assert(
	vim.tbl_contains(override.without_capabilities, "documentFormattingProvider"),
	"ts_ls no longer disables formatting"
)
local fake = { name = "ts_ls", server_capabilities = { documentFormattingProvider = true, hoverProvider = true } }
lsp.apply_overrides(fake)
equal(fake.server_capabilities.documentFormattingProvider, false, "ts_ls formatting was not cleared")
equal(fake.server_capabilities.hoverProvider, true, "ts_ls lost an unrelated capability")
local untouched = { name = "lua_ls", server_capabilities = { hoverProvider = true } }
lsp.apply_overrides(untouched)
equal(untouched.server_capabilities.hoverProvider, true, "override leaked to another server")

-- `<leader>e` is owned by the diagnostic float only.
for _, module in ipairs({
	"nazovim.lsp.diagnostics",
	"nazovim.lsp.symbols",
	"nazovim.lsp.calls",
	"nazovim.lsp.display",
	"nazovim.lsp.lifecycle",
}) do
	require(module).setup()
end
local leader_e = vim.fn.maparg("<leader>e", "n", false, true)
equal(leader_e.desc, "Show diagnostic", "unexpected <leader>e")

-- Commands offered by the new modules.
for _, command in ipairs({
	"NazoLspInfo",
	"NazoLspSymbols",
	"NazoLspReferences",
	"NazoLspIncomingCalls",
	"NazoLspOutgoingCalls",
	"NazoLspInlayHints",
	"NazoLspSemanticTokens",
	"NazoLspCodeLens",
	"NazoLspRestart",
	"NazoLspStop",
	"NazoLspStart",
}) do
	assert(vim.fn.exists(":" .. command) == 2, ":" .. command .. " is missing")
end

-- Buffer keymaps, including the ones that replaced duplicated defaults.
vim.cmd("enew")
vim.bo.filetype = "lua"
lsp.attach_keymaps(0, { name = "lua_ls" })
for _, lhs in ipairs({
	"K",
	"<leader>ld",
	"<leader>gr",
	"gD",
	"grw",
	"gO",
	"<leader>lT",
	"<leader>lci",
	"<leader>lco",
	"<leader>li",
	"<leader>lS",
	"<leader>lh",
	"<leader>lr",
	"<leader>lq",
}) do
	assert(vim.fn.maparg(lhs, "n") ~= "", "lsp keymap is missing: " .. lhs)
end
for _, lhs in ipairs({ "<leader>oi", "<leader>ru", "<leader>rr" }) do
	assert(vim.fn.maparg(lhs, "n") == "", lhs .. " leaked to an unrelated server")
end

-- Toggles stay harmless on a buffer without a client.
local notices = {}
local original_notify = vim.notify
vim.notify = function(message)
	notices[#notices + 1] = message
end
local display = require("nazovim.lsp.display")
display.toggle_inlay_hints()
assert(notices[#notices] == "Inlay hints: on", "inlay hint toggle did not report: " .. vim.inspect(notices))
display.toggle_inlay_hints()
assert(notices[#notices] == "Inlay hints: off", "inlay hint toggle did not flip")
display.toggle_semantic_tokens()
assert(notices[#notices]:find("Semantic tokens", 1, true), "semantic token toggle did not report")
display.toggle_codelens()
assert(notices[#notices]:find("Code lens", 1, true), "code lens toggle did not report")
vim.notify = original_notify

-- Call hierarchy items become line-level quickfix entries.
local calls = require("nazovim.lsp.calls")
local item = calls.item({
	uri = "file:///tmp/nazovim-calls.lua",
	name = "handler",
	selectionRange = { start = { line = 4, character = 7 } },
}, 2)
equal(item.filename, "/tmp/nazovim-calls.lua", "call item filename")
equal(item.lnum, 5, "call item line")
equal(item.text, "    handler", "call item indentation")

-- Lifecycle helpers are safe with no attached client.
local lifecycle = require("nazovim.lsp.lifecycle")
equal(lifecycle.names(0), {}, "lifecycle reported a client on a fresh buffer")

-- checkhealth stays quiet outside a health run.
require("nazovim.health").check()

print("lsp: servers, overrides, keymaps, toggles, calls and health passed")
