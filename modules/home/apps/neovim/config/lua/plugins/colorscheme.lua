return {
  "folke/tokyonight.nvim",
  lazy = false,
  priority = 1000, -- before the other start plugins
  config = function()
    vim.cmd("colorscheme tokyonight-night")
  end,
}
