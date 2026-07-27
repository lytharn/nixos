-- Bootstrap lazy.nvim, pinned to the commit in lazy-lock.json so a fresh
-- install reproduces the locked version instead of tracking live `stable`
-- (which rewrites the lockfile on first launch).
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"

  -- Pinned lazy.nvim commit from the lockfile, if any.
  local lazycommit
  local lockfile = io.open(vim.fn.stdpath("config") .. "/lazy-lock.json", "r")
  if lockfile then
    local ok, lock = pcall(vim.json.decode, lockfile:read("*a"))
    lockfile:close()
    if ok and lock["lazy.nvim"] then
      lazycommit = lock["lazy.nvim"].commit
    end
  end

  -- Pinned: clone the default branch (full history, blobs on demand) then
  -- check out the commit. Unpinned first-ever setup: fall back to `stable`.
  local clone = { "git", "clone", "--filter=blob:none", lazyrepo, lazypath }
  if not lazycommit then
    table.insert(clone, 3, "--branch=stable")
  end
  local out = vim.fn.system(clone)
  if vim.v.shell_error == 0 and lazycommit then
    out = vim.fn.system({ "git", "-C", lazypath, "checkout", lazycommit })
  end
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to bootstrap lazy.nvim:\n", "ErrorMsg" },
      { out,                                "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup("plugins")
