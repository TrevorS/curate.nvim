#!/usr/bin/env bash
# Run the curate.nvim test suite (busted, inside the nvim Lua runtime) + lint.
# Usage: scripts/test.sh [busted-args...]
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"
PLUGIN="$ROOT/curate.nvim"

# shellcheck disable=SC1091
[ -f "$HERE/dev-env.sh" ] && source "$HERE/dev-env.sh"
export PATH="$HOME/.luarocks/bin:/usr/local/bin:$PATH"
eval "$(luarocks path --local 2>/dev/null)"

cd "$PLUGIN" || exit 1

rc=0
echo "== luacheck =="
luacheck lua plugin spec --no-color || rc=1

echo "== busted (nlua: real vim API) =="
# nlua runs each spec inside headless Neovim, so vim.system / vim.api are live.
busted --lua=nlua "$@" || rc=1

# E2E scripts need a real RPC server loop (jj -> shim -> nvim --remote-expr),
# which nlua can't pump. Run them directly under `nvim -l`.
if [ -d spec/e2e ]; then
  for e2e in spec/e2e/*.lua; do
    echo "== e2e: $e2e =="
    timeout 120 nvim -l "$e2e" || rc=1
  done
fi

exit "$rc"
