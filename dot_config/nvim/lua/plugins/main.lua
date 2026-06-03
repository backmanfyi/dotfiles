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
        eslint = {
          root_dir = function(fname)
            local root = vim.fs.root(fname, {
              "eslint.config.js",
              "eslint.config.mjs",
              "eslint.config.cjs",
              "eslint.config.ts",
              "eslint.config.mts",
              "eslint.config.cts",
              ".eslintrc",
              ".eslintrc.js",
              ".eslintrc.cjs",
              ".eslintrc.json",
              ".eslintrc.yaml",
              ".eslintrc.yml",
              "package.json",
            })
            if not root then return nil end
            if vim.uv.fs_stat(root .. "/node_modules/eslint") then
              return root
            end
            return nil
          end,
        },
      },
    },
  },

  -- Silence "attempt to call field setup" warning from LazyVim's default dap spec
  -- https://stackoverflow.com/questions/77495184
  { "mfussenegger/nvim-dap", config = function() end },

  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = {
      linters = {
        ["markdownlint-cli2"] = {
          prepend_args = {
            "--config",
            vim.fn.stdpath("config") .. "/.markdownlint.jsonc",
          },
        },
      },
    },
  },
}
