-- Workaround for E31 errors when re-entering a markdown buffer: nvim's runtime
-- markdown.vim and markdown.lua both push unmaps of [[/]] into b:undo_ftplugin,
-- so the second LoadFTPlugin call double-unmaps them. sil! does not propagate
-- through the nested :exe correctly. Strip the duplicate unmap fragments.
local u = vim.b.undo_ftplugin or ""
u = u:gsub("|sil!%s*[nx]unmap%s*<buffer>%s*%[%[", "")
u = u:gsub("|sil!%s*[nx]unmap%s*<buffer>%s*%]%]", "")
u = u:gsub('sil!%s*exe%s*"nunmap <buffer> %]%]"%s*|%s*', "")
u = u:gsub('|%s*sil!%s*exe%s*"nunmap <buffer> %[%["', "")
vim.b.undo_ftplugin = u
