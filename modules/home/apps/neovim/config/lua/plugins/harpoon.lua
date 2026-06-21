return {
  "ThePrimeagen/harpoon",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  config = true,
  keys = {
    { "<leader>ja", function() require("harpoon.mark").add_file() end,        desc = "Mark file with harpoon" },
    { "<leader>jq", function() require("harpoon.ui").nav_file(1) end,         desc = "Go to harpoon mark 1" },
    { "<leader>jw", function() require("harpoon.ui").nav_file(2) end,         desc = "Go to harpoon mark 2" },
    { "<leader>je", function() require("harpoon.ui").nav_file(3) end,         desc = "Go to harpoon mark 3" },
    { "<leader>jr", function() require("harpoon.ui").nav_file(4) end,         desc = "Go to harpoon mark 4" },
    { "<leader>jl", function() require("harpoon.ui").toggle_quick_menu() end, desc = "Show harpoon mark list" },
  },
}
