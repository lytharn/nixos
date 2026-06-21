-- LSP plugins
return {
  {
    -- `lazydev` configures LuaLS for editing your Neovim config by
    -- lazily updating your workspace libraries.
    "folke/lazydev.nvim",
    ft = "lua",
    opts = {
      library = {
        -- Load luvit types when the `vim.uv` word is found
        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
        { path = "snacks.nvim",        words = { "Snacks" } },
      },
    },
  },
  { -- LSP Configuration
    "neovim/nvim-lspconfig",
    dependencies = {
      { "mason-org/mason.nvim", opts = {} },
      "mason-org/mason-lspconfig.nvim",
      "WhoIsSethDaniel/mason-tool-installer.nvim",
      "saghen/blink.cmp",

      -- Useful status updates for LSP.
      -- NOTE: `opts = {}` is the same as calling `require('fidget').setup({})`
      -- { 'j-hui/fidget.nvim', opts = {} },

    },
    config = function()
      -- This function gets run when an LSP attaches to a particular buffer.
      -- Every time a new buffer is opened that is associated with
      -- an lsp this function will be executed to configure the current buffer.
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

          -- Toggle inlay hints
          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf) then
            map("<leader>th", function()
              vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
            end, "[T]oggle Inlay [H]ints")
          end
        end,
      })

      -- See :help vim.diagnostic.Opts
      vim.diagnostic.config {
        severity_sort = true,
        float = {             -- Open with vim.diagnostic.open_float({opts})
          source = "if_many", -- Only show the source if there are multiple sources of diagnostics
        },
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
          source = "if_many", -- Only show the source if there are multiple sources of diagnostics
          spacing = 2,
        },
      }

      --  By default, Neovim doesn't support everything that is in the LSP specification.
      --  When you add blink.cmp, luasnip, etc. Neovim now has *more* capabilities.
      --  So, we create new capabilities with blink.cmp, and then broadcast that to the servers.
      local capabilities = require("blink.cmp").get_lsp_capabilities()

      -- Add any additional override configuration in the following tables. Available keys are:
      --  cmd (table): Override the default command used to start the server
      --  filetypes (table): Override the default list of associated filetypes for the server
      --  capabilities (table): Override fields in capabilities. Can be used to disable certain LSP features.
      --  settings (table): Override the default settings passed when initializing the server.
      local servers = {
        -- :help lspconfig-all for a list of all the pre-configured LSPs
        lua_ls = {
          -- cmd = {...},
          -- filetypes = { ...},
          -- capabilities = {},
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


      -- To check the current status of installed tools and/or manually install
      -- other tools, you can run
      --   :Mason
      -- You can press `g?` for help in this menu.
      local servers_to_install = {}
      local ensure_installed = vim.tbl_keys(servers_to_install or {})
      vim.list_extend(ensure_installed, {})
      require("mason-tool-installer").setup { ensure_installed = ensure_installed }

      for server, opts in pairs(servers) do
        opts.capabilities = vim.tbl_deep_extend("force", {}, capabilities, opts.capabilities or {})
        vim.lsp.config(server, opts)
        vim.lsp.enable(server)
      end
    end,
  } }
