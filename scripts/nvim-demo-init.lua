-- Minimal nvim init for demos/screenshots: put curate.nvim on the runtimepath,
-- load a dark colorscheme, and call setup(). Used by VHS tapes.
local plugin = vim.env.CURATE_PLUGIN or (vim.fn.getcwd() .. "/curate.nvim")
vim.opt.runtimepath:prepend(plugin)
vim.opt.runtimepath:append(plugin) -- ensure ftplugin/after resolve too

vim.o.termguicolors = true
vim.o.number = false
vim.o.laststatus = 0
vim.o.cmdheight = 0
vim.o.fillchars = "eob: " -- hide end-of-buffer ~ for cleaner captures

-- Theme: honor CURATE_COLORSCHEME (e.g. "catppuccin"), optionally loading a
-- colorscheme plugin from CURATE_COLORSCHEME_PATH first; else fall back to
-- habamax which ships with nvim. curate links its groups to the colorscheme, so
-- any dark theme works — this just makes demos/screenshots reproducible.
if vim.env.CURATE_COLORSCHEME_PATH then
  vim.opt.runtimepath:prepend(vim.env.CURATE_COLORSCHEME_PATH)
end
local scheme = vim.env.CURATE_COLORSCHEME or "habamax"
if not pcall(vim.cmd.colorscheme, scheme) then
  vim.cmd.colorscheme("habamax")
end

require("curate").setup({})
