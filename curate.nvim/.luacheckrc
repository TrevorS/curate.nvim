-- Luacheck config for curate.nvim
std = "luajit"
cache = true
codes = true

-- Neovim + busted globals
globals = { "vim" }
read_globals = {
  "describe", "it", "before_each", "after_each", "setup", "teardown",
  "assert", "pending", "spy", "stub", "mock", "finally",
}

-- The plugin re-renders whole buffers and uses long jj template strings.
max_line_length = 140
ignore = {
  "212", -- unused argument (callbacks frequently ignore args)
  "631", -- line too long (template literals)
}

exclude_files = { "spec/helpers/*" }
