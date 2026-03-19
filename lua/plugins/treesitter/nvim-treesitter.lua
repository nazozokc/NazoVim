return {
	{
		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
		event = { "BufReadPost", "BufNewFile" },
		opts = {
			parser_install_dir = vim.fn.stdpath("data") .. "/site",
			ensure_installed = {
				"javascript",
				"typescript",
				"tsx",
				"java",
				"python",
				"json",
				"html",
				"css",
				"lua",
				"vim",
				"vimdoc",
				"regex",
				"bash",
			},

			highlight = {
				enable = true,
				additional_vim_regex_highlighting = false,
			},

			indent = {
				enable = true,
			},

			textobjects = {
				select = {
					enable = true,
					lookahead = true,
					keymaps = {
						["af"] = { query = "@function.outer", desc = "outer function" },
						["if"] = { query = "@function.inner", desc = "inner function" },
						["ac"] = { query = "@class.outer", desc = "outer class" },
						["ic"] = { query = "@class.inner", desc = "inner class" },
						["ai"] = { query = "@conditional.outer", desc = "outer conditional" },
						["ii"] = { query = "@conditional.inner", desc = "inner conditional" },
						["al"] = { query = "@loop.outer", desc = "outer loop" },
						["il"] = { query = "@loop.inner", desc = "inner loop" },
						["aa"] = { query = "@parameter.outer", desc = "outer argument" },
						["ia"] = { query = "@parameter.inner", desc = "inner argument" },
						["ab"] = { query = "@block.outer", desc = "outer block" },
						["ib"] = { query = "@block.inner", desc = "inner block" },
					},
				},

				move = {
					enable = true,
					set_jumps = true,
					goto_next_start = {
						["]f"] = { query = "@function.outer", desc = "Next function start" },
						["]c"] = { query = "@class.outer", desc = "Next class start" },
						["]a"] = { query = "@parameter.inner", desc = "Next argument start" },
					},
					goto_next_end = {
						["]F"] = { query = "@function.outer", desc = "Next function end" },
						["]C"] = { query = "@class.outer", desc = "Next class end" },
					},
					goto_previous_start = {
						["[f"] = { query = "@function.outer", desc = "Prev function start" },
						["[c"] = { query = "@class.outer", desc = "Prev class start" },
						["[a"] = { query = "@parameter.inner", desc = "Prev argument start" },
					},
					goto_previous_end = {
						["[F"] = { query = "@function.outer", desc = "Prev function end" },
						["[C"] = { query = "@class.outer", desc = "Prev class end" },
					},
				},

				swap = {
					enable = true,
					swap_next = {
						["<leader>sn"] = { query = "@parameter.inner", desc = "Swap next argument" },
					},
					swap_previous = {
						["<leader>sp"] = { query = "@parameter.inner", desc = "Swap prev argument" },
					},
				},
			},

			incremental_selection = {
				enable = true,
				keymaps = {
					init_selection = "gnn",
					node_incremental = "grn",
					scope_incremental = "grc",
					node_decremental = "grm",
				},
			},
		},
	},
}
