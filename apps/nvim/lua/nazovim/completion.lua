local M = {}

---Return whether an LSP client can complete in this buffer.
---@param bufnr? integer
---@return boolean
local function lsp_ready(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
		if client:supports_method("textDocument/completion", bufnr) then
			return true
		end
	end
	return false
end

---Return the text typed before the cursor that can be completed.
local function typed_prefix()
	local line = vim.api.nvim_get_current_line()
	local col = vim.api.nvim_win_get_cursor(0)[2]
	return line:sub(1, col):match("([%w_%-%./~]*)$") or "", col
end

---Collect identifiers from the current buffer that start with `prefix`.
---@param prefix string
local function buffer_items(prefix)
	local seen, items = {}, {}
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	for _, line in ipairs(lines) do
		for word in line:gmatch("[%a_][%w_]*") do
			if word ~= prefix and word:sub(1, #prefix) == prefix and not seen[word] then
				seen[word] = true
				items[#items + 1] = { word = word, kind = "v", menu = "[BUF]" }
			end
		end
	end
	return items
end

---Collect file paths that start with `prefix`.
---@param prefix string
local function path_items(prefix)
	local items, seen = {}, {}
	for _, path in ipairs(vim.fn.glob(prefix .. "*", false, true)) do
		if not seen[path] then
			seen[path] = true
			local directory = vim.fn.isdirectory(path) == 1
			items[#items + 1] = {
				word = path .. (directory and "/" or ""),
				kind = directory and "d" or "f",
				menu = "[PATH]",
			}
		end
	end
	return items
end

---Collect snippet prefixes that start with `prefix`.
---@param prefix string
local function snippet_items(prefix)
	local items = {}
	for _, definition in ipairs(require("nazovim.snippets").candidates(prefix)) do
		items[#items + 1] = {
			word = definition.prefix,
			abbr = definition.prefix,
			menu = "[SNIP]",
			kind = "S",
			info = definition.description,
			user_data = { snippet = definition.prefix },
		}
	end
	return items
end

---Collect completion items for a typed prefix.
---@param prefix string
---@return table[]
function M.items(prefix)
	if prefix:find("/", 1, true) then
		return path_items(prefix)
	end
	local items = snippet_items(prefix)
	vim.list_extend(items, buffer_items(prefix))
	return items
end

---Complete snippets, buffer words and file paths with the built-in popup menu.
function M.complete()
	local prefix, col = typed_prefix()
	local items = M.items(prefix)
	if #items == 0 then
		return false
	end
	vim.fn.complete(col - #prefix, items)
	return true
end

---Trigger completion: LSP when available, otherwise the built-in sources.
function M.trigger()
	if lsp_ready() then
		vim.lsp.completion.get()
		return
	end
	M.complete()
end

local function popup_visible()
	return vim.fn.pumvisible() == 1
end

local function accept()
	return popup_visible() and "<C-y>" or "<CR>"
end

local function tab()
	if popup_visible() then
		return "<C-y>"
	end
	local snippets = require("nazovim.snippets")
	if snippets.jumpable(1) then
		snippets.jump(1)
		return ""
	end
	return "<Tab>"
end

local function shift_tab()
	local snippets = require("nazovim.snippets")
	if snippets.jumpable(-1) then
		snippets.jump(-1)
		return ""
	end
	return "<S-Tab>"
end

---Expand a snippet accepted from the built-in menu.
local function on_complete_done()
	local item = vim.v.completed_item
	if type(item) ~= "table" then
		return
	end
	local data = item.user_data
	if type(data) ~= "table" or type(data.snippet) ~= "string" then
		return
	end
	vim.schedule(function()
		require("nazovim.snippets").expand_trigger(data.snippet)
	end)
end

function M.setup()
	vim.opt.completeopt = { "menu", "menuone", "noselect", "popup" }

	vim.keymap.set("i", "<C-Space>", M.trigger, { desc = "Complete" })
	vim.keymap.set("i", "<CR>", accept, { expr = true, desc = "Accept completion" })
	vim.keymap.set("i", "<Tab>", tab, { expr = true, desc = "Accept completion or jump" })
	vim.keymap.set("i", "<S-Tab>", shift_tab, { expr = true, desc = "Jump to previous stop" })

	local group = vim.api.nvim_create_augroup("NazoCompletion", { clear = true })
	vim.api.nvim_create_autocmd("LspAttach", {
		group = group,
		desc = "Enable the built-in LSP completion for attached clients",
		callback = function(args)
			local client = vim.lsp.get_client_by_id(args.data.client_id)
			if not client or not client:supports_method("textDocument/completion", args.buf) then
				return
			end
			vim.lsp.completion.enable(true, client.id, args.buf, { autotrigger = true })
		end,
	})
	vim.api.nvim_create_autocmd("CompleteDone", {
		group = group,
		desc = "Expand a snippet picked from the completion menu",
		callback = on_complete_done,
	})
end

return M
