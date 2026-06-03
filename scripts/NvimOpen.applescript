-- NvimOpen.applescript
-- Opens files in Neovim inside a tmux session in Ghostty.
-- Compiled to ~/Applications/NvimOpen.app by chezmoi run_onchange_after_06.

on open fileList
    repeat with theFile in fileList
        set filePath to POSIX path of theFile
        do shell script "$HOME/.config/dotfiles/scripts/nvim-open.sh " & quoted form of filePath
    end repeat
end open

on run
    -- Launched without files (e.g. directly from Finder) — nothing to do
end run
