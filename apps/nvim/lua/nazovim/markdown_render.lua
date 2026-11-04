local M = {}

local namespace = vim.api.nvim_create_namespace("NazoVimMarkdownRender")
local disabled = {}
local timers = {}
local heading_icons = { "󰎤", "󰎧", "󰎪", "󰎭", "󰎱", "󰎳" }

local function supported(buf)
	local ft = vim.bo[buf].filetype
	return ft == "markdown" or ft == "Avante"
end

local function mark(buf, row, opts)
	local col = opts.col or 0
	local extmark_opts = vim.deepcopy(opts)
	extmark_opts.col = nil
	vim.api.nvim_buf_set_extmark(buf, namespace, row, col, extmark_opts)
end

local function render_table(buf, lines, first, last)
	local rows, widths = {}, {}
	for row = first, last do
		local line = lines[row]
		local cells = {}
		for cell in line:gmatch("|([^|]*)") do
			cells[#cells + 1] = vim.trim(cell)
		end
		if line:sub(-1) == "|" and #cells > 0 then
			table.remove(cells)
		end
		rows[#rows + 1] = { row = row - 1, cells = cells }
		for index, cell in ipairs(cells) do
			if not cell:match("^:?-+:?$") then
				widths[index] = math.max(widths[index] or 3, vim.fn.strdisplaywidth(cell))
			end
		end
	end
	local separator_cells = {}
	for index, width in ipairs(widths) do
		separator_cells[index] = string.rep("─", math.max(3, width))
	end
	for index, row in ipairs(rows) do
		local is_separator = true
		for _, cell in ipairs(row.cells) do
			if not cell:match("^:?-+:?$") then
				is_separator = false
				break
			end
		end
		local display
		if is_separator then
			display = "├" .. table.concat(separator_cells, "┼") .. "┤"
		else
			local cells = {}
			for column, width in ipairs(widths) do
				local cell = row.cells[column] or ""
				cells[#cells + 1] = cell .. string.rep(" ", math.max(0, width - vim.fn.strdisplaywidth(cell)))
			end
			display = "│ " .. table.concat(cells, " │ ") .. " │"
		end
		mark(buf, row.row, {
			virt_text = { { display, is_separator and "FloatBorder" or (index == 1 and "Title" or "Normal") } },
			virt_text_pos = "overlay",
			hl_mode = "replace",
			priority = 110,
		})
	end
end

local function render(buf)
	if not vim.api.nvim_buf_is_valid(buf) or not supported(buf) then
		return
	end
	vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
	if disabled[buf] then
		return
	end
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local in_fence, row = false, 1
	while row <= #lines do
		local line = lines[row]
		local fence = line:match("^%s*(```+)") or line:match("^%s*(~~~+)")
		if fence then
			in_fence = not in_fence
			mark(buf, row - 1, { line_hl_group = "Comment" })
		elseif in_fence then
			mark(buf, row - 1, {
				line_hl_group = "NazoMarkdownCode",
				virt_text = { { "  ", "NazoMarkdownCode" } },
				virt_text_pos = "inline",
				priority = 40,
			})
			local width = vim.fn.strdisplaywidth(line)
			local padding = math.max(0, 80 - width - 4)
			mark(buf, row - 1, {
				virt_text = { { string.rep(" ", padding + 2), "NazoMarkdownCode" } },
				virt_text_pos = "eol",
				priority = 40,
			})
		elseif line:match("^%s*|") then
			local last = row
			while last < #lines and lines[last + 1]:match("^%s*|") do
				last = last + 1
			end
			render_table(buf, lines, row, last)
			row = last
		else
			local indent, hashes = line:match("^(%s*)(#+)%s+")
			if hashes and #hashes <= 6 then
				mark(buf, row - 1, {
					col = #indent,
					virt_text = { { heading_icons[#hashes] .. " ", "Title" } },
					virt_text_pos = "inline",
					priority = 50,
				})
				mark(buf, row - 1, { line_hl_group = "NazoMarkdownHeading" .. #hashes, priority = 30 })
			end

			local prefix, checkbox = line:match("^(%s*[-*+]%s+)%[([ xX~])%]")
			if checkbox then
				local icon, highlight = "☐  ", "DiagnosticInfo"
				if checkbox == "x" or checkbox == "X" then
					icon, highlight = "☑  ", "DiagnosticOk"
				elseif checkbox == "~" then
					icon, highlight = "◷  ", "DiagnosticWarn"
				end
				mark(buf, row - 1, {
					col = #prefix,
					virt_text = { { icon, highlight } },
					virt_text_pos = "overlay",
					hl_mode = "replace",
					priority = 100,
					end_col = #prefix + 3,
				})
			else
				local bullet_indent, bullet = line:match("^(%s*)([-*+])%s+")
				if bullet then
					mark(buf, row - 1, {
						col = #bullet_indent,
						virt_text = { { bullet == "-" and "•" or (bullet == "*" and "◦" or "▪"), "Special" } },
						virt_text_pos = "overlay",
						hl_mode = "replace",
						priority = 80,
						end_col = #bullet_indent + 1,
					})
				end
			end

			local quote_indent = line:match("^(%s*)>%s?")
			if quote_indent then
				local col = #quote_indent
				mark(buf, row - 1, {
					col = col,
					virt_text = { { "┃", "DiagnosticInfo" } },
					virt_text_pos = "overlay",
					hl_mode = "replace",
					priority = 85,
					end_col = col + 1,
				})
			end

			local image_col = line:find("!%[[^%]]*%]%([^)]*%)")
			if image_col then
				mark(buf, row - 1, {
					col = image_col - 1,
					virt_text = { { "󰥶 ", "Special" } },
					virt_text_pos = "inline",
					priority = 45,
				})
			else
				local link_col = line:find("%[[^%]]+%]%([^)]*%)")
				if link_col then
					mark(buf, row - 1, {
						col = link_col - 1,
						virt_text = { { "󰌹 ", "Underlined" } },
						virt_text_pos = "inline",
						priority = 44,
					})
				end
			end
		end
		row = row + 1
	end
end

local function schedule(buf)
	local timer = timers[buf]
	if not timer then
		timer = vim.uv.new_timer()
		timers[buf] = timer
	end
	timer:stop()
	timer:start(
		80,
		0,
		vim.schedule_wrap(function()
			if vim.api.nvim_buf_is_valid(buf) then
				render(buf)
			end
		end)
	)
end

---Toggle rich Markdown decorations in the current Markdown or Avante buffer.
function M.toggle()
	local buf = vim.api.nvim_get_current_buf()
	if not supported(buf) then
		vim.notify("Rich rendering is available in Markdown and Avante buffers", vim.log.levels.INFO, {
			title = "NazoVim Markdown",
		})
		return
	end
	disabled[buf] = not disabled[buf]
	if disabled[buf] then
		vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
	else
		schedule(buf)
	end
end

---Set highlight defaults and install rendering for Markdown and Avante buffers.
function M.setup()
	vim.api.nvim_set_hl(0, "NazoMarkdownCode", { link = "NormalFloat", default = true })
	for level = 1, 6 do
		vim.api.nvim_set_hl(0, "NazoMarkdownHeading" .. level, {
			link = level == 1 and "Title" or "Normal",
			default = true,
		})
	end
	local group = vim.api.nvim_create_augroup("NazoVimMarkdownRender", { clear = true })
	vim.api.nvim_create_autocmd("FileType", {
		group = group,
		pattern = { "markdown", "Avante" },
		callback = function(event)
			schedule(event.buf)
		end,
	})
	vim.api.nvim_create_autocmd({ "BufEnter", "TextChanged", "TextChangedI" }, {
		group = group,
		callback = function(event)
			if supported(event.buf) then
				schedule(event.buf)
			end
		end,
	})
	vim.api.nvim_create_autocmd("BufWipeout", {
		group = group,
		callback = function(event)
			disabled[event.buf] = nil
			if timers[event.buf] then
				timers[event.buf]:stop()
				timers[event.buf]:close()
				timers[event.buf] = nil
			end
		end,
	})
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = group,
		callback = function()
			vim.api.nvim_set_hl(0, "NazoMarkdownCode", { link = "NormalFloat", default = true })
			for level = 1, 6 do
				vim.api.nvim_set_hl(0, "NazoMarkdownHeading" .. level, {
					link = level == 1 and "Title" or "Normal",
					default = true,
				})
			end
		end,
	})
	vim.api.nvim_create_user_command("NazoMarkdownRenderToggle", M.toggle, { desc = "Toggle rich Markdown rendering" })
	vim.keymap.set("n", "<leader>um", M.toggle, { desc = "Toggle rich Markdown rendering" })
end

return M
