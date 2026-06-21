return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  ---@type snacks.Config
  opts = {
    picker = { -- This enables the picker
      win = {
        input = {
          keys = {
            -- <C-g> to switch between live and fzf search
            -- <Tab> to select files
            ["<Esc>"] = { "close", mode = { "i", "n" } }, -- Close picker with Esc
            ["<C-j>"] = { "history_forward", mode = { "i", "n" } },
            ["<C-k>"] = { "history_back", mode = { "i", "n" } },
            ["<C-y>"] = { "confirm", mode = { "i", "n" } },
          },
        },
      },
    },
    rename = {},
    words = {},
  },
  init = function()
    -- Lets LSP clients know that a file has been renamed
    vim.api.nvim_create_autocmd("User", {
      pattern = "MiniFilesActionRename",
      callback = function(event)
        Snacks.rename.on_rename_file(event.data.from, event.data.to)
      end,
    })
  end,
  keys = {
    -- Picker
    --
    -- find files
    { "<leader><space>", function() Snacks.picker.smart() end,   desc = "Smart Find Files" },
    { "<leader>fb",      function() Snacks.picker.buffers() end, desc = "Buffers" },
    { "<leader>,",       function() Snacks.picker.buffers() end, desc = "Buffers" },
    {
      "<leader>fc",
      function()
        Snacks.picker.files(
          { cwd = vim.fn.stdpath("config") })
      end,
      desc = "Find Config File",
    },
    { "<leader>ff", function() Snacks.picker.files() end,                 desc = "Find Files" },
    { "<leader>fr", function() Snacks.picker.recent() end,                desc = "Recent" },
    -- git
    { "<leader>gb", function() Snacks.picker.git_branches() end,          desc = "Git Branches" },
    { "<leader>gl", function() Snacks.picker.git_log() end,               desc = "Git Log" },
    { "<leader>gL", function() Snacks.picker.git_log_line() end,          desc = "Git Log Line" },
    { "<leader>gs", function() Snacks.picker.git_status() end,            desc = "Git Status" },
    { "<leader>gS", function() Snacks.picker.git_stash() end,             desc = "Git Stash" },
    { "<leader>gd", function() Snacks.picker.git_diff() end,              desc = "Git Diff (Hunks)" },
    { "<leader>gf", function() Snacks.picker.git_log_file() end,          desc = "Git Log File" },
    -- search
    { '<leader>s"', function() Snacks.picker.registers() end,             desc = "Registers" },
    { "<leader>s/", function() Snacks.picker.search_history() end,        desc = "Search History" },
    { "<leader>sa", function() Snacks.picker.autocmds() end,              desc = "Autocmds" },
    { "<leader>sb", function() Snacks.picker.lines() end,                 desc = "Buffer Lines" },
    { "<leader>sB", function() Snacks.picker.grep_buffers() end,          desc = "Grep Open Buffers" },
    { "<leader>sc", function() Snacks.picker.command_history() end,       desc = "Command History" },
    { "<leader>sC", function() Snacks.picker.commands() end,              desc = "Commands" },
    { "<leader>sd", function() Snacks.picker.diagnostics() end,           desc = "Diagnostics" },
    { "<leader>sD", function() Snacks.picker.diagnostics_buffer() end,    desc = "Buffer Diagnostics" },
    { "<leader>sg", function() Snacks.picker.grep() end,                  desc = "Grep" },
    { "<leader>/",  function() Snacks.picker.grep() end,                  desc = "Grep" },
    { "<leader>sh", function() Snacks.picker.help() end,                  desc = "Help Pages" },
    { "<leader>sH", function() Snacks.picker.highlights() end,            desc = "Highlights" },
    { "<leader>si", function() Snacks.picker.icons() end,                 desc = "Icons" },
    { "<leader>sj", function() Snacks.picker.jumps() end,                 desc = "Jumps" },
    { "<leader>sk", function() Snacks.picker.keymaps() end,               desc = "Keymaps" },
    { "<leader>sl", function() Snacks.picker.loclist() end,               desc = "Location List" },
    { "<leader>sm", function() Snacks.picker.marks() end,                 desc = "Marks" },
    { "<leader>sM", function() Snacks.picker.man() end,                   desc = "Man Pages" },
    { "<leader>sp", function() Snacks.picker.lazy() end,                  desc = "Search for Plugin Spec" },
    { "<leader>sq", function() Snacks.picker.qflist() end,                desc = "Quickfix List" },
    { "<leader>sR", function() Snacks.picker.resume() end,                desc = "Resume" },
    { "<leader>s.", function() Snacks.picker.resume() end,                desc = "Resume" },
    { "<leader>st", function() Snacks.picker.colorschemes() end,          desc = "Colorschemes" },
    { "<leader>su", function() Snacks.picker.undo() end,                  desc = "Undo History" },
    { "<leader>sw", function() Snacks.picker.grep_word() end,             desc = "Visual selection or word", mode = { "n", "x" } },
    -- LSP
    { "gd",         function() Snacks.picker.lsp_definitions() end,       desc = "Goto Definition" },
    { "gD",         function() Snacks.picker.lsp_declarations() end,      desc = "Goto Declaration" },
    { "gr",         function() Snacks.picker.lsp_references() end,        nowait = true,                     desc = "References" },
    { "gI",         function() Snacks.picker.lsp_implementations() end,   desc = "Goto Implementation" },
    { "gy",         function() Snacks.picker.lsp_type_definitions() end,  desc = "Goto T[y]pe Definition" },
    { "<leader>ss", function() Snacks.picker.lsp_symbols() end,           desc = "LSP Symbols" },
    { "<leader>sS", function() Snacks.picker.lsp_workspace_symbols() end, desc = "LSP Workspace Symbols" },

    -- Words
    { "]]",         function() Snacks.words.jump(vim.v.count1) end,       desc = "Next Reference" },
    { "[[",         function() Snacks.words.jump(-vim.v.count1) end,      desc = "Prev Reference" },
  },
}
