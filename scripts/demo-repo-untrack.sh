#!/usr/bin/env bash
# Throwaway jj repo for the "file untrack" screenshot: a build artifact that got
# committed and later gitignored, so it shows in the working-copy tree and `K`
# can untrack it. Prints the repo path. (Sibling of demo-repo.sh.)
set -uo pipefail
DIR="${1:-$(mktemp -d /tmp/curate-untrack.XXXXXX)}"
rm -rf "$DIR" && mkdir -p "$DIR"
export HOME="${DEMO_HOME:-$DIR/.home}"; mkdir -p "$HOME"
cd "$DIR" || exit 1
jj git init . >/dev/null 2>&1
jj config set --user user.name  "Curate Demo"       >/dev/null 2>&1
jj config set --user user.email "demo@curate.nvim"  >/dev/null 2>&1

printf '.home/\n' > .gitignore # keep the demo HOME out of the working copy
printf 'local M = {}\nfunction M.run() end\nreturn M\n' > app.lua
jj describe -m "feat: app" >/dev/null 2>&1
jj new >/dev/null 2>&1

# A build artifact that slipped into the commit: write it and snapshot so jj
# tracks it, THEN gitignore it — now it's tracked-but-ignored, the thing `K`
# untracks.
printf 'compiled junk\n' > build.log
jj status >/dev/null 2>&1 # snapshot → build.log is now tracked
printf 'src = require("app")\n' > main.lua
printf '.home/\n*.log\n' > .gitignore

echo "$DIR"
