return {
	"mfussenegger/nvim-lint",
	event = { "BufWritePost", "BufNewFile" },
	config = function()
		local lint = require("lint")
		lint.linters_by_ft = {
			javascript = { "eslint" },
			javascriptreact = { "eslint" },
			typescript = { "eslint" },
			typescriptreact = { "eslint" },
			ruby = { "rubocop" },
			lua = { "luacheck" },
			nix = { "nix" },
			markdown = { "markdownlint" },
		}

		vim.api.nvim_create_autocmd({ "BufWritePost" }, {
			callback = function()
				lint.try_lint()
			end,
		})
	end,
}
