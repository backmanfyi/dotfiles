return {
  { "EdenEast/nightfox.nvim", lazy = false, priority = 1000 },

  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "dawnfox",
    },
  },

  {
    "neovim/nvim-lspconfig",
    ---@class PluginLspOpts
    opts = {
      ---@type lspconfig.options
      servers = {
        basedpyright = {},
      },
    },
  },

  { import = "lazyvim.plugins.extras.lang.docker" },
  { import = "lazyvim.plugins.extras.lang.git" },
  { import = "lazyvim.plugins.extras.lang.go" },
  { import = "lazyvim.plugins.extras.lang.terraform" },
  { import = "lazyvim.plugins.extras.lang.toml" },
  { import = "lazyvim.plugins.extras.lang.typescript" },
  { import = "lazyvim.plugins.extras.lang.yaml" },

  -- Silence "attempt to call field setup" warning from LazyVim's default dap spec
  -- https://stackoverflow.com/questions/77495184
  { "mfussenegger/nvim-dap", config = function() end },
}
