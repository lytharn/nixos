return {
  {
    "mfussenegger/nvim-dap",
    config = function()
      local dap = require("dap")
      dap.adapters.lldb = {
        type = "executable",
        command = vim.fn.exepath("lldb-dap"),
        name = "lldb",
      }
    end,
    keys = {
      { "<leader>dl", function() require("dap").step_into() end,                                            desc = "Step into" },
      { "<leader>dh", function() require("dap").step_out() end,                                             desc = "Step out" },
      { "<leader>dj", function() require("dap").step_over() end,                                            desc = "Step over" },
      { "<leader>dk", function() require("dap").step_back() end,                                            desc = "Step over" },
      { "<leader>dz", function() require("dap").run_to_cursor() end,                                        desc = "Run to cursor" },
      { "<leader>dc", function() require("dap").continue() end,                                             desc = "Continue" },
      { "<leader>db", function() require("dap").toggle_breakpoint() end,                                    desc = "Toggle breakpoint" },
      { "<leader>dd", function() require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: ")) end, desc = "Set conditional breakpoint" },
      { "<leader>dt", function() require("dap").terminate() end,                                            desc = "Terminate" },
      { "<leader>dr", function() require("dap").run_last() end,                                             desc = "Run last" },
    },
  },
  {
    "rcarriga/nvim-dap-ui",
    dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },
    config = function()
      local dap, dapui = require("dap"), require("dapui")
      dapui.setup()
      dap.listeners.before.attach.dapui_config = function()
        dapui.open()
      end
      dap.listeners.before.launch.dapui_config = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated.dapui_config = function()
        dapui.close()
      end
      dap.listeners.before.event_exited.dapui_config = function()
        dapui.close()
      end
    end,
  },
  {
    "mfussenegger/nvim-dap-python",
    config = function()
      local dapp = require("dap-python")
      dapp.setup("python3")
    end,
  },
}
