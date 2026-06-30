-- Minimal nvim init for demos/screenshots: put curate.nvim on the runtimepath,
-- load a dark colorscheme, and call setup(). Used by VHS tapes.
local plugin = vim.env.CURATE_PLUGIN or (vim.fn.getcwd() .. "/curate.nvim")
vim.opt.runtimepath:prepend(plugin)
vim.opt.runtimepath:append(plugin) -- ensure ftplugin/after resolve too

vim.o.termguicolors = true
vim.o.number = false
vim.o.laststatus = 0
vim.o.cmdheight = 0
vim.cmd("colorscheme habamax") -- ships with nvim; dark, close enough to Tokyo Night for a demo

require("curate").setup({})
