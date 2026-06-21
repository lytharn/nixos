-- Clear highlight search by escaping in normal mode
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

-- Better window navigation
vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "Move to window left of current" })
vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "Move to window below" })
vim.keymap.set("n", "<C-k>", "<C-w>k", { desc = "Move to window above" })
vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "Move to window right of current" })

-- Open float
vim.keymap.set("n", "<leader>od", vim.diagnostic.open_float, { desc = "Open diagnostic" })

-- Quickfix keymaps
vim.keymap.set("n", "<leader>qd", vim.diagnostic.setqflist, { desc = "Open diagnostic quickfix list" })
vim.keymap.set("n", "<leader>qq", "<cmd>cclose<CR>", { desc = "Close quickfix list" })
vim.keymap.set("n", "<leader>qo", "<cmd>copen<CR><C-w>p", { desc = "Open quickfix list" })
vim.keymap.set("n", "<A-j>", "<cmd>cnext<CR>", { desc = "Next quickfix item" })     -- Default ]q
vim.keymap.set("n", "<A-k>", "<cmd>cprev<CR>", { desc = "Previous quickfix item" }) -- Default [q

-- Do not copy what is replaced with paste
vim.keymap.set("v", "p", '"_dP')

-- Stay in indent mode
vim.keymap.set("v", "<", "<gv")
vim.keymap.set("v", ">", ">gv")
