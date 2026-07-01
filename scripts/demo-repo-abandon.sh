#!/usr/bin/env bash
# Throwaway jj repo for the "abandon" screenshot: an independent scratch change
# sits between a base and the real work, so abandoning it reparents @ cleanly
# (no conflict). Prints the repo path. (Sibling of demo-repo.sh.)
set -uo pipefail
DIR="${1:-$(mktemp -d /tmp/curate-abandon.XXXXXX)}"
rm -rf "$DIR" && mkdir -p "$DIR"
export HOME="${DEMO_HOME:-$DIR/.home}"; mkdir -p "$HOME"
cd "$DIR" || exit 1
jj git init . >/dev/null 2>&1
jj config set --user user.name  "Curate Demo"       >/dev/null 2>&1
jj config set --user user.email "demo@curate.nvim"  >/dev/null 2>&1

printf 'local M = {}\nreturn M\n' > app.lua
jj describe -m "feat: app" >/dev/null 2>&1

# a throwaway spike touching only scratch.txt — the change we'll abandon
jj new -m "wip: scratch experiment" >/dev/null 2>&1
printf 'a throwaway spike\n' > scratch.txt

# the real work on top, editing app.lua (independent of scratch.txt)
jj new -m "feat: real work" >/dev/null 2>&1
printf 'local M = {}\nfunction M.run() end\nreturn M\n' > app.lua

echo "$DIR"
