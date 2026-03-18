return {
  "hrsh7th/cmp-cmdline",
  -- CmdlineEnter は削除。nvim-cmp が InsertEnter でロードされた後に
  -- after/plugin として自動ロードされるよう dependencies に任せる
  dependencies = { "hrsh7th/nvim-cmp" },
  config = function()
    local ok, cmp = pcall(require, "cmp")
    if not ok then
      return
    end

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
