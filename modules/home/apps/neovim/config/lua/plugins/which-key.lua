return { -- Useful plugin to show you pending keybinds.
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    spec = {
      {
        mode = { "n", "v" },
        { "<leader>c", group = "[C]ode" },
        { "<leader>d", group = "[D]ebug" },
        { "<leader>f", group = "[F]ind files" },
        { "<leader>g", group = "[G]it" },
        { "<leader>h", group = "[H]unk" },
        { "<leader>j", group = "[J]ump" },
        { "<leader>l", group = "[L]ivePreview" },
        { "<leader>q", group = "[O]open" },
        { "<leader>q", group = "[Q]uickfix" },
        { "<leader>s", group = "[S]earch" },
        { "<leader>t", group = "[T]oggle" },
      },
    },
  },
  keys = {
    {
      "<leader>?",
      function()
        require("which-key").show({ global = false })
      end,
      desc = "Buffer Local Keymaps (which-key)",
    },
  },
}
