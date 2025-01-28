return {
	{ "EdenEast/nightfox.nvim" },

	-- Configure LazyVim to load gruvbox
	{
		"LazyVim/LazyVim",
		opts = {
			colorscheme = "dawnfox",
		},
	},

	-- change some telescope options and a keymap to browse plugin files
	{
		"nvim-telescope/telescope.nvim",
	},

	-- add basedpyright to lspconfig
	{
		"neovim/nvim-lspconfig",
		---@class PluginLspOpts
		opts = {
			---@type lspconfig.options
			servers = {
				-- pyright will be automatically installed with mason and loaded with lspconfig
				basedpyright = {},
			},
		},
	},

	-- EXTRAS
	{ import = "lazyvim.plugins.extras.lang.docker" },
	{ import = "lazyvim.plugins.extras.lang.git" },
	{ import = "lazyvim.plugins.extras.lang.go" },
	{ import = "lazyvim.plugins.extras.lang.json" },
	{ import = "lazyvim.plugins.extras.lang.markdown" },
	{ import = "lazyvim.plugins.extras.lang.python" },
	{ import = "lazyvim.plugins.extras.lang.terraform" },
	{ import = "lazyvim.plugins.extras.lang.toml" },
	{ import = "lazyvim.plugins.extras.lang.typescript" },
	{ import = "lazyvim.plugins.extras.lang.yaml" },

	{
		{
			-- Silence warning
			-- https://stackoverflow.com/questions/77495184/nvim-failed-to-run-config-for-nvim-dap-loader-lua369-attemp-to-call-field-s
			"mfussenegger/nvim-dap",
			config = function() end,
		},
	},

	{
		"gpanders/editorconfig.nvim",
		event = "VeryLazy",
	},
}
