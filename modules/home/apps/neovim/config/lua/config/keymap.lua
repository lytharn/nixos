-- Clear highlight search by escaping in normal mode
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>")

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
