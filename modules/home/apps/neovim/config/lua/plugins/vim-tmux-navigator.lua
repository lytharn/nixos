return {
  "christoomey/vim-tmux-navigator",
  cmd = {
    "TmuxNavigateLeft",
    "TmuxNavigateDown",
    "TmuxNavigateUp",
    "TmuxNavigateRight",
    "TmuxNavigatePrevious",
  },
  keys = {
    { "<C-h>",  "<cmd>TmuxNavigateLeft<cr>",     desc = "Navigate pane left" },
    { "<C-j>",  "<cmd>TmuxNavigateDown<cr>",     desc = "Navigate pane down" },
    { "<C-k>",  "<cmd>TmuxNavigateUp<cr>",       desc = "Navigate pane up" },
    { "<C-l>",  "<cmd>TmuxNavigateRight<cr>",    desc = "Navigate pane right" },
    { "<C-\\>", "<cmd>TmuxNavigatePrevious<cr>", desc = "Navigate to previous pane" },
  },
}
