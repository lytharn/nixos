return {
  "nvim-lualine/lualine.nvim",
  dependencies = {
    "nvim-tree/nvim-web-devicons",
    -- Code context in the winbar
    {
      "SmiteshP/nvim-navic",
      opts = {
        highlight = true,
        separator = "  ",
        lsp = { auto_attach = true },
      },
    },
  },
  opts = {
    options = {
      globalstatus = true,
    },
    sections = {
      lualine_c = {
        "lsp_status",
      },
    },
    winbar = {
      lualine_a = {},
      lualine_b = {},
      lualine_c = {
        { "filename", path = 1 },
        {
          function() return require("nvim-navic").get_location() end,
          cond = function() return require("nvim-navic").is_available() end,
        },
      },
      lualine_x = {},
      lualine_y = {},
      lualine_z = {},
    },
    inactive_winbar = {
      lualine_a = {},
      lualine_b = {},
      lualine_c = { "filename" },
      lualine_x = {},
      lualine_y = {},
      lualine_z = {},
    },
  },
}
