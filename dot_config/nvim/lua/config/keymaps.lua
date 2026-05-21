-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- cd to current file's directory (window-local)
vim.keymap.set("n", "<leader>cd", "<cmd>lcd %:p:h<cr>", { desc = "cd to file dir (local)" })

-- Paste over selection without clobbering the unnamed register
vim.keymap.set("x", "<leader>p", [["_dP]], { desc = "Paste without yanking" })
