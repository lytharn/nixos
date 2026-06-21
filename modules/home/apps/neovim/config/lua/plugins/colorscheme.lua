return {
  {
    "folke/tokyonight.nvim",
    lazy = false,    -- This is the main colorscheme make sure it is loaded during startup
    priority = 1000, -- Load before all other start plugins
    config = function()
      vim.cmd("colorscheme tokyonight-night")
    end,
  },
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = true,
  },
  {
    "lunarvim/darkplus.nvim",
    lazy = true,
  },
}
