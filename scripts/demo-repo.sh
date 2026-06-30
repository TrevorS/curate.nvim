#!/usr/bin/env bash
# Create a deterministic throwaway jj repo for tests and screenshots.
# Prints the repo path on stdout. Pass a path to reuse a fixed location.
set -uo pipefail
DIR="${1:-$(mktemp -d /tmp/curate-demo.XXXXXX)}"
rm -rf "$DIR" && mkdir -p "$DIR"
export HOME="${DEMO_HOME:-$DIR/.home}"
mkdir -p "$HOME"

cd "$DIR" || exit 1
# Keep the in-repo demo HOME (nvim state, jj user config) out of the working copy
# so it never shows up as a change in screenshots.
printf '.home/\n*.log\n' > .gitignore
jj git init . >/dev/null 2>&1
jj config set --user user.name  "Curate Demo"  >/dev/null 2>&1
jj config set --user user.email "demo@curate.nvim" >/dev/null 2>&1

# Build a small but realistic history: two described ancestors, then a messy @.
printf 'local M = {}\nfunction M.collect() end\nreturn M\n' > hunks.lua
jj describe -m "feat: hunk collector" >/dev/null 2>&1
jj new -m "feat: status view" >/dev/null 2>&1
printf 'local M = {}\nfunction M.render() end\nreturn M\n' > status.lua
jj new >/dev/null 2>&1
# working-copy edits spanning two files (the diff the plugin curates)
printf 'local M = {}\nfunction M.collect()\n  local sel = {}\n  return sel\nend\nfunction M.apply() end\nreturn M\n' > hunks.lua
printf 'local M = {}\nfunction M.render()\n  return "status"\nend\nreturn M\n' > status.lua
printf 'return require("curate")\n' > init.lua

echo "$DIR"
