-- View Markdown, HTML (with CSS, JavaScript) and AsciiDoc files in a web browser with live updates.
return {
  "brianhuster/live-preview.nvim",
  keys = {
    { "<leader>ls", "<CMD>LivePreview start<CR>", mode = "", desc = "[L]ivePreview [S]tart" },
    { "<leader>lc", "<CMD>LivePreview close<CR>", mode = "", desc = "[L]ivePreview [C]lose" },
    { "<leader>lp", "<CMD>LivePreview pick<CR>",  mode = "", desc = "[L]ivePreview [P]ick" },
  },
};
