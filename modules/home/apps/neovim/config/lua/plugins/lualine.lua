return {
  "nvim-lualine/lualine.nvim",
  dependencies = {
    -- Enable nice icons
    "nvim-tree/nvim-web-devicons",

    -- Enable progress of LSP
    "arkav/lualine-lsp-progress",

    -- Enable code context
    {
      "SmiteshP/nvim-navic",
      opts = {
        -- Add colors to icons and text as defined by highlight groups NavicIcons*
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
        "lsp_progress",
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
