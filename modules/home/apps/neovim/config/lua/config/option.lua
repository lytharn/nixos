-- Must be set before plugins are loaded
vim.g.mapleader = " "      -- Remap leader key for global plugins
vim.g.maplocalleader = " " -- Remap leader key for filetype plugins

-- Ignore case in search patterns unless they contain upper case
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Absolute number on the cursor line, relative elsewhere
vim.opt.number = true
vim.opt.relativenumber = true

vim.opt.mouse = "a"

vim.opt.splitbelow = true
vim.opt.splitright = true

vim.opt.cursorline = true

-- Persist undo history across sessions
vim.opt.undofile = true

-- Swap write and CursorHold delay
vim.opt.updatetime = 250

vim.opt.timeoutlen = 600

vim.opt.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- Preview substitutions in a split
vim.opt.inccommand = "split"

vim.opt.scrolloff = 10

vim.opt.winborder = "rounded"
