return {
  {
    -- LuaLS types for the Neovim config itself
    "folke/lazydev.nvim",
    ft = "lua",
    opts = {
      library = {
        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
        { path = "snacks.nvim",        words = { "Snacks" } },
      },
    },
  },
  {
    -- The servers' default configs (lsp/*.lua). The servers themselves come from Nix
    -- (modules/home/apps/neovim/default.nix); blink.cmp adds its capabilities to all of them.
    "neovim/nvim-lspconfig",
    dependencies = { "saghen/blink.cmp" },
    config = function()
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("lytharn-lsp-attach", { clear = true }),
        callback = function(event)
          local map = function(keys, func, desc, mode)
            mode = mode or "n"
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
          end

          map("<leader>cr", vim.lsp.buf.rename, "[R]ename")
          map("<leader>ca", vim.lsp.buf.code_action, "[C]ode [A]ction", { "n", "x" })
          map("<leader>qi", vim.lsp.buf.incoming_calls, "Open incoming calls quickfix list")

          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf) then
            map("<leader>th", function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
            end, "[T]oggle Inlay [H]ints")
          end

          -- Toggle between a C/C++ source file and its header. Backed by clangd's
          -- textDocument/switchSourceHeader extension, which nvim-lspconfig's clangd
          -- config exposes as the buffer-local :LspClangdSwitchSourceHeader command.
          if client and client.name == "clangd" then
            map("gh", "<cmd>LspClangdSwitchSourceHeader<CR>", "[G]o to [H]eader/source")
          end
        end,
      })

      -- See :help vim.diagnostic.Opts
      vim.diagnostic.config {
        severity_sort = true,
        float = { source = "if_many" },
        underline = { severity = vim.diagnostic.severity.ERROR },
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = "󰅚 ",
            [vim.diagnostic.severity.WARN] = "󰀪 ",
            [vim.diagnostic.severity.INFO] = "󰋽 ",
            [vim.diagnostic.severity.HINT] = "󰌶 ",
          },
        },
        virtual_lines = {
          current_line = true,
        },
        virtual_text = {
          source = "if_many",
          spacing = 2,
        },
      }

      -- Overrides of nvim-lspconfig's defaults (:help lspconfig-all)
      local servers = {
        clangd = {
          cmd = {
            "clangd",
            -- Index the whole project in the background, not just open files, so
            -- references/symbol search cover files that were never opened.
            "--background-index",
            -- Run clang-tidy in-process (picks up a project's .clang-tidy).
            "--clang-tidy",
            "--completion-style=detailed",
            "--function-arg-placeholders=1",
            -- Only insert #include on completion when the header is genuinely
            -- needed for the symbol. iwyu stands for include-what-you-use.
            "--header-insertion=iwyu",
          },
          init_options = {
            -- Used for files that compile_commands.json doesn't cover (scratch
            -- files, a project without a compilation database).
            fallbackFlags = { "-std=c++23" },
          },
        },
        lua_ls = {
          settings = {
            Lua = {
              format = {
                defaultConfig = {
                  quote_style = "double",
                  call_arg_parantheses = "unambiguous_remove_string_only",
                  trailing_table_separator = "smart",
                },
              },
              workspace = {
                checkThirdParty = false,
              },
            },
          },
        },
        marksman = {},
        nixd = {},
        pyright = {
          settings = {
            pyright = {
              -- Let Ruff handle import sorting
              disableOrganizeImports = true,
            },
            python = {
              analysis = {
                -- Let Ruff handle linting diagnostics
                ignore = { "*" },
              },
            },
          },
        },
        ruff = {},
      }

      for server, opts in pairs(servers) do
        vim.lsp.config(server, opts)
        vim.lsp.enable(server)
      end
    end,
  } }
