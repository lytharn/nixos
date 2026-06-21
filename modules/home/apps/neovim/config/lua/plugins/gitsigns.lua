return {
  "lewis6991/gitsigns.nvim",
  opts = {
    signs = {
      add          = { text = "▎" },
      change       = { text = "▎" },
      delete       = { text = "󰐊" },
      topdelete    = { text = "󰐊" },
      changedelete = { text = "▎" },
      untracked    = { text = "┆" },
    },
    current_line_blame = true,
    on_attach = function(bufnr)
      local gitsigns = require("gitsigns")

      local function map(mode, l, r, opts)
        opts = opts or {}
        opts.buffer = bufnr
        vim.keymap.set(mode, l, r, opts)
      end

      -- Navigation
      map("n", "]c", function()
        if vim.wo.diff then
          vim.cmd.normal({ "]c", bang = true })
        else
          gitsigns.nav_hunk("next")
        end
      end, { desc = "Move to next hunk" })

      map("n", "[c", function()
        if vim.wo.diff then
          vim.cmd.normal({ "[c", bang = true })
        else
          gitsigns.nav_hunk("prev")
        end
      end, { desc = "Move to previous hunk" })

      -- Actions
      map("n", "<leader>hs", gitsigns.stage_hunk, { desc = "Stage hunk" })
      map("n", "<leader>hr", gitsigns.reset_hunk, { desc = "Reset hunk" })
      map("v", "<leader>hs", function() gitsigns.stage_hunk { vim.fn.line("."), vim.fn.line("v") } end,
        { desc = "Stage hunk" })
      map("v", "<leader>hr", function() gitsigns.reset_hunk { vim.fn.line("."), vim.fn.line("v") } end,
        { desc = "Reset hunk" })
      map("n", "<leader>hS", gitsigns.stage_buffer, { desc = "Stage buffer" })
      map("n", "<leader>hR", gitsigns.reset_buffer, { desc = "Reset buffer" })
      map("n", "<leader>hp", gitsigns.preview_hunk, { desc = "Preview hunk" })
      map("n", "<leader>hi", gitsigns.preview_hunk_inline, { desc = "Preview hunk inline" })
      map("n", "<leader>hh", function() gitsigns.change_base("HEAD", true) end,
        { desc = "Change hunk preview base to HEAD" })
      map("n", "<leader>hP", function() gitsigns.change_base("~", true) end,
        { desc = "Change hunk preview base to parent" })
      map("n", "<leader>hb", function() gitsigns.blame_line { full = true } end, { desc = "Blame on current line" })
      map("n", "<leader>tb", gitsigns.toggle_current_line_blame, { desc = "Toggle line blame virtual text" })
      map("n", "<leader>hsd", gitsigns.diffthis, { desc = "Show buffer diff" })
      map("n", "<leader>hsD", function() gitsigns.diffthis("~") end, { desc = "Show buffer diff with parent" })
      map("n", "<leader>hsb", gitsigns.blame, { desc = "Show blame" })
      map("n", "<leader>hQ", function() gitsigns.setqflist("all") end, { desc = "Open all changes quickfix list" })
      map("n", "<leader>hq", gitsigns.setqflist, { desc = "Open buffer changes quickfix list" })

      -- Text object
      map({ "o", "x" }, "ih", gitsigns.select_hunk, { desc = "Select hunk" })
    end,
  },
}
