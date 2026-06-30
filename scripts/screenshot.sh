#!/usr/bin/env bash
# Drive Neovim through a VHS tape and emit PNG/GIF screenshots of curate.nvim.
#
#   scripts/screenshot.sh <tape-file> [out-dir]
#
# Tapes live in scripts/tape/*.tape. Each tape boots nvim with the plugin on the
# runtimepath against a throwaway jj repo (created by scripts/demo-repo.sh) so the
# captures show real plugin state, not a mock.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"

# shellcheck disable=SC1091
[ -f "$HERE/dev-env.sh" ] && source "$HERE/dev-env.sh"
export PATH="$HOME/.luarocks/bin:/usr/local/bin:$PATH"

TAPE="${1:?usage: screenshot.sh <tape> [out-dir]}"
TAPE="$(cd "$(dirname "$TAPE")" && pwd)/$(basename "$TAPE")"  # absolutise before cd
OUT="${2:-$ROOT/screenshots}"
mkdir -p "$OUT"

# Exported so VHS tapes (which inherit this environment via ttyd) can locate the
# repo root and the plugin on the runtimepath.
export CURATE_ROOT="$ROOT"
export CURATE_PLUGIN="$ROOT/curate.nvim"

# VHS resolves Output/Screenshot paths relative to CWD; run from the out dir.
cd "$OUT" || exit 1
echo "== vhs $TAPE -> $OUT =="
vhs "$TAPE"
echo "== artifacts =="
ls -la "$OUT"
