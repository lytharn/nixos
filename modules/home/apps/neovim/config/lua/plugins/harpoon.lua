return {
  "ThePrimeagen/harpoon",
  branch = "harpoon2",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  config = function()
    require("harpoon"):setup()
  end,
  keys = {
    { "<leader>ja", function() require("harpoon"):list():add() end,    desc = "Mark file with harpoon" },
    { "<leader>jq", function() require("harpoon"):list():select(1) end, desc = "Go to harpoon mark 1" },
    { "<leader>jw", function() require("harpoon"):list():select(2) end, desc = "Go to harpoon mark 2" },
    { "<leader>je", function() require("harpoon"):list():select(3) end, desc = "Go to harpoon mark 3" },
    { "<leader>jr", function() require("harpoon"):list():select(4) end, desc = "Go to harpoon mark 4" },
    {
      "<leader>jl",
      function() require("harpoon").ui:toggle_quick_menu(require("harpoon"):list()) end,
      desc = "Show harpoon mark list",
    },
  },
}
