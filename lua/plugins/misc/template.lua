return {
	"nvimdev/template.nvim",
	cmd = { "Template", "TemplateProject" },
	config = function()
		require("template").setup({
			temp_dir = vim.fn.stdpath("config") .. "/template",
			author = "nazozo",
			email = "hoge@example.com",

			variables = {
				["_year_"] = function()
					return os.date("%Y")
				end,
				["_date_"] = function()
					return os.date("%Y-%m-%d")
				end,
			},
		})
	end,
}
