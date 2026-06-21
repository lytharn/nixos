return {
  "stevearc/conform.nvim",
  event = { "BufWritePre" },
  cmd = { "ConformInfo" },
  keys = {
    {
      "<leader>cf",
      function()
        require("conform").format({ async = true, lsp_fallback = true })
      end,
      mode = "",
      desc = "[C]ode [F]ormat",
    },
  },
  opts = {
    -- Set up format-on-save
    format_on_save = { timeout_ms = 500, lsp_format = "fallback" },
  },
}
