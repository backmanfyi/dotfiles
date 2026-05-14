-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua

local augroup = vim.api.nvim_create_augroup("user_autocmds", { clear = true })

-- Strip trailing whitespace on save, except where it's significant
vim.api.nvim_create_autocmd("BufWritePre", {
  group = augroup,
  callback = function(ev)
    local skip = { markdown = true, diff = true, gitcommit = true, mail = true, ["snacks_dashboard"] = true }
    if skip[vim.bo[ev.buf].filetype] then
      return
    end
    local view = vim.fn.winsaveview()
    vim.cmd([[silent! keeppatterns %s/\s\+$//e]])
    vim.fn.winrestview(view)
  end,
})

-- <CR> in quickfix jumps and closes the quickfix window
vim.api.nvim_create_autocmd("FileType", {
  group = augroup,
  pattern = { "qf" },
  callback = function(ev)
    vim.keymap.set("n", "<CR>", "<CR>:cclose<CR>", { buffer = ev.buf, silent = true })
  end,
})
