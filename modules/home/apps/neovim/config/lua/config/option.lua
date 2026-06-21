-- Must be set before plugins are loaded
vim.g.mapleader = " "      -- Remap leader key for global plugins
vim.g.maplocalleader = " " -- Remap leader key for filetype plugins

-- Ignore case in search patterns if no upper case
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Show relative line numbers
vim.opt.number = true
vim.opt.relativenumber = true

-- Highlight search matches
vim.opt.hlsearch = true

-- Allow mouse usage
vim.opt.mouse = "a"

-- Horizontal splits go below current window
vim.opt.splitbelow = true

-- Vertical splits go to the right of current window
vim.opt.splitright = true

-- Highlight current line
vim.opt.cursorline = true

-- Save undo history to file when writing a buffer to a file, and restore undo history from the same file on buffer read.
vim.opt.undofile = true

-- If nothing is typed for this many ms, swap will be written do disk. Also used for CursorHold autocommand event.
vim.opt.updatetime = 250

-- Time in ms to wait for a key code sequence to complete
vim.opt.timeoutlen = 600

-- Show whitespace characters: tab, trailing space and non-breakable space
vim.opt.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- Preview substitutions in a separate window
vim.opt.inccommand = "split"

-- Minimal number of screen lines to keep above and below the cursor
vim.opt.scrolloff = 10

-- Use rounded borders on all floating windows
vim.opt.winborder = "rounded"
