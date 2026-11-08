return {
  "stevearc/conform.nvim",
  event = { "BufWritePre" },
  cmd = { "ConformInfo" },
  keys = {
    {
      "<leader>cf",
      function()
        require("conform").format({ async = true, lsp_format = "fallback" })
      end,
      mode = "",
      desc = "[C]ode [F]ormat",
    },
  },
  opts = {
    format_on_save = { timeout_ms = 500, lsp_format = "fallback" },
  },
}
