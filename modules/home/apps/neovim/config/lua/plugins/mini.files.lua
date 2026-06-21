return {
  "echasnovski/mini.files",
  version = false,
  lazy = false, -- Load mini.files so it can replace netrw
  keys = {
    { "<leader>e", function() require("mini.files").open() end, desc = "Open explorer" },
  },
  opts = {},
}
