return {
	{
		"zigtools/zls",
		ft = { "zig" },
		config = function()
			require("lspconfig").zls.setup({
				settings = {
					zls = {
						enable_inlay_hints = true,
						enable_snippets = true,
						warn_style = true,
					},
				},
			})
		end,
	},
}
