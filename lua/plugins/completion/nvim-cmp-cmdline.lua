return {
	"hrsh7th/cmp-cmdline",
	event = "CmdlineEnter",
	-- dependencies に nvim-cmp を書かない
	config = function()
		local ok, cmp = pcall(require, "cmp")
		if not ok then
			return
		end -- cmp未ロードなら何もしない

		cmp.setup.cmdline("/", {
			mapping = cmp.mapping.preset.cmdline(),
			sources = cmp.config.sources({
				{ name = "buffer" },
			}),
			completion = { completeopt = "menu,menuone,noselect" },
		})

		cmp.setup.cmdline(":", {
			mapping = cmp.mapping.preset.cmdline(),
			sources = cmp.config.sources({ { name = "path" } }, { { name = "cmdline" } }),
			completion = { completeopt = "menu,menuone,noselect" },
		})
	end,
}
