return {
  -- add more treesitter parsers
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "bash",
        "dockerfile",
        "hcl",
        "helm",
        "html",
        "javascript",
        "json",
        "lua",
        "markdown",
        "markdown_inline",
        "ninja",
        "python",
        "query",
        "regex",
        "rst",
        "terraform",
        "tsx",
        "typescript",
        "vim",
        "yaml",
      },
    },
  },
}
