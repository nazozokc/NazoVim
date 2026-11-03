local M = {}

local filetypes = {
	asciidoc = true,
	gitcommit = true,
	gitrebase = true,
	help = true,
	mail = true,
	markdown = true,
	norg = true,
	org = true,
	rst = true,
	text = true,
	tex = true,
	typst = true,
}

---Whether spell checking should be enabled for a filetype.
function M.wanted(filetype)
	return filetypes[filetype] == true
end

---Apply the spell setting to every window showing one buffer.
---`spell` is window-local, so hidden buffers are handled when they appear.
function M.apply(buf)
	if not buf or buf == 0 then
		buf = vim.api.nvim_get_current_buf()
	end
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	local enabled = vim.g.nazovim_spell ~= false and M.wanted(vim.bo[buf].filetype)
	for _, win in ipairs(vim.fn.win_findbuf(buf)) do
		if vim.api.nvim_win_is_valid(win) then
			vim.wo[win].spell = enabled
		end
	end
end

---Toggle spell checking for prose buffers.
function M.toggle()
	vim.g.nazovim_spell = not (vim.g.nazovim_spell ~= false)
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		M.apply(buf)
	end
	vim.notify("Spell checking " .. (vim.g.nazovim_spell ~= false and "enabled" or "disabled"))
end

function M.setup()
	if vim.g.nazovim_spell == nil then
		vim.g.nazovim_spell = true
	end
	vim.api.nvim_create_user_command("SpellToggle", M.toggle, { desc = "Toggle prose spell checking" })
	local group = vim.api.nvim_create_augroup("NazoSpell", { clear = true })
	vim.api.nvim_create_autocmd({ "FileType", "BufEnter", "WinEnter" }, {
		group = group,
		callback = function(args)
			M.apply(args.buf)
		end,
	})
end

return M
