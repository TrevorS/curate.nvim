#!/usr/bin/env bash
# Throwaway jj repo for the "injections" screenshot: a Markdown doc whose working
# copy adds a ```lua fenced example, and a Lua file that adds a vim.cmd([[ ... ]])
# block. The diff-editor then shows three languages at once — Markdown, Lua
# (inside the fence), and vimscript (inside vim.cmd). Prints the repo path.
set -uo pipefail
DIR="${1:-$(mktemp -d /tmp/curate-inject.XXXXXX)}"
rm -rf "$DIR" && mkdir -p "$DIR"
export HOME="${DEMO_HOME:-$DIR/.home}"; mkdir -p "$HOME"
cd "$DIR" || exit 1
printf '.home/\n*.log\n' > .gitignore
jj git init . >/dev/null 2>&1
jj config set --user user.name  "Curate Demo"       >/dev/null 2>&1
jj config set --user user.email "demo@curate.nvim"  >/dev/null 2>&1

cat > README.md <<'MD'
# acme.nvim

A tiny plugin.

## Install

Use your favourite plugin manager.
MD
cat > theme.lua <<'LUA'
local M = {}

function M.setup()
  vim.o.termguicolors = true
end

return M
LUA
jj describe -m "docs: readme + theme stub" >/dev/null 2>&1
jj new -m "docs: usage example + highlights" >/dev/null 2>&1

cat > README.md <<'MD'
# acme.nvim

A tiny plugin.

## Install

Use your favourite plugin manager.

## Usage

Call `setup()` from your config:

```lua
require("acme").setup({
  theme = "mocha",
  on_attach = function(buf)
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, { buffer = buf })
  end,
})
```

That's all you need.
MD
cat > theme.lua <<'LUA'
local M = {}

function M.setup()
  vim.o.termguicolors = true

  vim.cmd([[
    highlight AcmeTitle guifg=#89b4fa gui=bold
    highlight AcmeMuted guifg=#6c7086
    sign define AcmeMark text=> texthl=AcmeTitle
  ]])
end

return M
LUA

echo "$DIR"
