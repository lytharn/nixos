-- Treesitter, post-archival of nvim-treesitter (Apr 2026).
--
-- We no longer use the archived nvim-treesitter parser aggregator:
--   * Parsers + queries are provided reproducibly by Nix (see the neovim
--     home module: modules/home/apps/neovim/default.nix), placed on the
--     runtimepath under $XDG_DATA_HOME/nvim/site.
--   * Highlighting is Neovim 0.12's built-in treesitter (vim.treesitter.start).
--   * Text objects come from nvim-treesitter-textobjects, which is still
--     maintained, runs on core treesitter, and ships its own textobjects.scm.
return {
  "nvim-treesitter/nvim-treesitter-textobjects",
  branch = "main",
  lazy = false,
  init = function()
    -- Disable built-in ftplugin mappings to avoid conflicts.
    -- See https://github.com/nvim-treesitter/nvim-treesitter-textobjects
    vim.g.no_plugin_maps = true
  end,
  config = function()
    -- Enable treesitter highlighting for any filetype that has a parser
    -- (the Nix-provided ones, plus Neovim's built-ins). pcall so a filetype
    -- without a parser/query just falls back to legacy syntax highlighting.
    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("lytharn-treesitter-highlight", { clear = true }),
      callback = function(args)
        pcall(vim.treesitter.start, args.buf)
      end,
    })

    -- Some Nix-provided grammar queries were authored for nvim-treesitter and
    -- use its `#is-not?` predicate (e.g. tree-sitter-nix's highlights.scm does
    -- `(#is-not? @variable.builtin local)`). Core treesitter has no handler for
    -- it, so without this every matching buffer throws "No handler for is-not?"
    -- mid-highlight. We dropped nvim-treesitter's locals machinery, so register
    -- a pragmatic stub: treat every node as "not a local", i.e. `#is-not? local`
    -- always passes -> builtins/keywords stay highlighted even when a local of
    -- the same name shadows them (`let map = ...`), which is rare and cosmetic.
    -- (`is-not?` is the only non-core predicate any of our grammars use.)
    pcall(vim.treesitter.query.add_predicate, "is-not?", function()
      return true
    end, { force = true })

    -- On the `main` branch, setup() only takes `select`/`move` options;
    -- keymaps are defined manually below via the module APIs.
    require("nvim-treesitter-textobjects").setup({
      select = {
        -- Automatically jump forward to textobj.
        lookahead = true,
      },
      move = {
        set_jumps = true, -- Set jumps in the jumplist, can use C-o/C-i
      },
    })

    -- Select. Capture groups are defined in the bundled textobjects.scm.
    local select = require("nvim-treesitter-textobjects.select")
    local select_keys = {
      ["a="] = { "@assignment.outer", "Select outer part of an assignment" },
      ["i="] = { "@assignment.inner", "Select inner part of an assignment" },
      ["l="] = { "@assignment.lhs", "Select left hand side of an assignment" },
      ["r="] = { "@assignment.rhs", "Select right hand side of an assignment" },

      ["aa"] = { "@parameter.outer", "Select outer part of a parameter/argument" },
      ["ia"] = { "@parameter.inner", "Select inner part of a parameter/argument" },

      ["ai"] = { "@conditional.outer", "Select outer part of a conditional" },
      ["ii"] = { "@conditional.inner", "Select inner part of a conditional" },

      ["al"] = { "@loop.outer", "Select outer part of a loop" },
      ["il"] = { "@loop.inner", "Select inner part of a loop" },

      ["af"] = { "@call.outer", "Select outer part of a function call" },
      ["if"] = { "@call.inner", "Select inner part of a function call" },

      ["am"] = { "@function.outer", "Select outer part of a method/function definition" },
      ["im"] = { "@function.inner", "Select inner part of a method/function definition" },

      ["ac"] = { "@class.outer", "Select outer part of a class" },
      ["ic"] = { "@class.inner", "Select inner part of a class" },
    }
    for lhs, spec in pairs(select_keys) do
      vim.keymap.set({ "x", "o" }, lhs, function()
        select.select_textobject(spec[1], "textobjects")
      end, { desc = spec[2] })
    end

    -- Swap.
    local swap = require("nvim-treesitter-textobjects.swap")
    vim.keymap.set("n", "<leader>na", function()
      swap.swap_next("@parameter.inner")
    end, { desc = "Swap parameter/argument with next" })
    vim.keymap.set("n", "<leader>nm", function()
      swap.swap_next("@function.outer")
    end, { desc = "Swap function with next" })
    vim.keymap.set("n", "<leader>pa", function()
      swap.swap_previous("@parameter.inner")
    end, { desc = "Swap parameter/argument with previous" })
    vim.keymap.set("n", "<leader>pm", function()
      swap.swap_previous("@function.outer")
    end, { desc = "Swap function with previous" })

    -- Move.
    local move = require("nvim-treesitter-textobjects.move")
    local move_keys = {
      goto_next_start = {
        ["]f"] = { "@call.outer", "Next function call start" },
        ["]m"] = { "@function.outer", "Next method/function def start" },
        ["]c"] = { "@class.outer", "Next class start" },
        ["]i"] = { "@conditional.outer", "Next conditional start" },
        ["]l"] = { "@loop.outer", "Next loop start" },
      },
      goto_next_end = {
        ["]F"] = { "@call.outer", "Next function call end" },
        ["]M"] = { "@function.outer", "Next method/function def end" },
        ["]C"] = { "@class.outer", "Next class end" },
        ["]I"] = { "@conditional.outer", "Next conditional end" },
        ["]L"] = { "@loop.outer", "Next loop end" },
      },
      goto_previous_start = {
        ["[f"] = { "@call.outer", "Prev function call start" },
        ["[m"] = { "@function.outer", "Prev method/function def start" },
        ["[c"] = { "@class.outer", "Prev class start" },
        ["[i"] = { "@conditional.outer", "Prev conditional start" },
        ["[l"] = { "@loop.outer", "Prev loop start" },
      },
      goto_previous_end = {
        ["[F"] = { "@call.outer", "Prev function call end" },
        ["[M"] = { "@function.outer", "Prev method/function def end" },
        ["[C"] = { "@class.outer", "Prev class end" },
        ["[I"] = { "@conditional.outer", "Prev conditional end" },
        ["[L"] = { "@loop.outer", "Prev loop end" },
      },
    }
    for fn, keys in pairs(move_keys) do
      for lhs, spec in pairs(keys) do
        vim.keymap.set({ "n", "x", "o" }, lhs, function()
          move[fn](spec[1], "textobjects")
        end, { desc = spec[2] })
      end
    end

    -- Repeat movements with ; and ,
    local repeatable_move = require("nvim-treesitter-textobjects.repeatable_move")
    vim.keymap.set({ "n", "x", "o" }, ";", repeatable_move.repeat_last_move)
    vim.keymap.set({ "n", "x", "o" }, ",", repeatable_move.repeat_last_move_opposite)

    -- Maintain builtin f, F, t, T also repeatable with ; and ,
    vim.keymap.set({ "n", "x", "o" }, "f", repeatable_move.builtin_f_expr, { expr = true })
    vim.keymap.set({ "n", "x", "o" }, "F", repeatable_move.builtin_F_expr, { expr = true })
    vim.keymap.set({ "n", "x", "o" }, "t", repeatable_move.builtin_t_expr, { expr = true })
    vim.keymap.set({ "n", "x", "o" }, "T", repeatable_move.builtin_T_expr, { expr = true })
  end,
}
