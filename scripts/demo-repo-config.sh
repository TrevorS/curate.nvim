#!/usr/bin/env bash
# Throwaway jj repo for the "rich diff" screenshot: a Lua config whose working
# copy tweaks several values and renames a couple of identifiers, so the
# diff-editor shows treesitter syntax + intra-line (word-level) emphasis on the
# exact tokens that changed. Prints the repo path. (Sibling of demo-repo.sh.)
set -uo pipefail
DIR="${1:-$(mktemp -d /tmp/curate-config.XXXXXX)}"
rm -rf "$DIR" && mkdir -p "$DIR"
export HOME="${DEMO_HOME:-$DIR/.home}"; mkdir -p "$HOME"
cd "$DIR" || exit 1
printf '.home/\n*.log\n' > .gitignore
jj git init . >/dev/null 2>&1
jj config set --user user.name  "Curate Demo"       >/dev/null 2>&1
jj config set --user user.email "demo@curate.nvim"  >/dev/null 2>&1

cat > config.lua <<'LUA'
local M = {}

M.options = {
  theme = "dark",
  font_size = 12,
  tab_width = 4,
  wrap = false,
  timeout = 250,
  keymaps = { save = "<C-s>", quit = "<C-q>" },
}

function M.apply(opts)
  M.options = vim.tbl_extend("force", M.options, opts or {})
end

return M
LUA
jj describe -m "config: defaults" >/dev/null 2>&1
jj new -m "config: tune defaults" >/dev/null 2>&1

cat > config.lua <<'LUA'
local M = {}

M.defaults = {
  theme = "catppuccin-mocha",
  font_size = 14,
  tab_width = 2,
  wrap = true,
  timeout = 400,
  keymaps = { save = "<C-s>", quit = "<C-c>" },
}

function M.setup(opts)
  M.defaults = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
LUA

echo "$DIR"
