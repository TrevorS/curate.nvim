#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# bootstrap-dev-env.sh — provision everything needed to build, test, and
# screenshot the curate.nvim plugin inside an ephemeral Claude Code (web) box.
#
# Idempotent: safe to run repeatedly. Each step checks before installing.
#
# Installs:
#   - Neovim 0.12+        (prebuilt, /opt/nvim)         — design targets 0.11+
#   - jujutsu (jj) latest (prebuilt musl)               — the VCS we drive
#   - lua5.1 + luarocks   (apt)                         — module runtime
#   - busted + nlua       (luarocks --local)            — tests w/ real vim API
#   - luacheck            (apt)                         — linter
#   - stylua              (prebuilt)                    — formatter
#   - tmux                (apt)                         — drive nvim headless
#   - vhs + ttyd + ffmpeg (prebuilt/apt)                — PNG/GIF screenshots
#   - chromium shim       (/usr/local/bin/chromium)     — go-rod browser for vhs
#
# Why a script and not Docker: this sandbox has a docker CLI but no reachable
# daemon (no nested containers), so a reproducible provisioning script is the
# portable path. Re-run it from a fresh box and you're back in business.
# ---------------------------------------------------------------------------
set -uo pipefail

log()  { printf '\033[1;36m[bootstrap]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[bootstrap]\033[0m %s\n' "$*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

SUDO=""
[ "$(id -u)" -ne 0 ] && SUDO="sudo"

ARCH="$(uname -m)"  # expect x86_64

# Retry a curl download with exponential backoff (handles flaky networks).
fetch() { # fetch <url> <out>
  local url="$1" out="$2" tries=0 delay=2
  while [ "$tries" -lt 4 ]; do
    if curl -fsSL --connect-timeout 20 -o "$out" "$url"; then return 0; fi
    tries=$((tries + 1)); warn "fetch failed ($url), retry $tries in ${delay}s"; sleep "$delay"; delay=$((delay * 2))
  done
  return 1
}

# ---------------------------------------------------------------------------
log "1/9 apt base packages"
# The base image ships broken third-party PPAs (deadsnakes/ondrej 403) that
# abort `apt update`; quarantine them so the main archive resolves.
$SUDO mkdir -p /etc/apt/disabled-ppas
$SUDO find /etc/apt/sources.list.d/ -type f \( -name '*deadsnakes*' -o -name '*ondrej*' \) \
  -exec mv {} /etc/apt/disabled-ppas/ \; 2>/dev/null || true
if ! have nvim || ! have luarocks || ! have ffmpeg || ! have tmux || ! have luacheck; then
  $SUDO apt-get update -qq || warn "apt update had warnings"
  $SUDO apt-get install -y -qq \
    lua5.1 liblua5.1-0-dev luajit luarocks lua-check \
    ffmpeg tmux curl git unzip ca-certificates || warn "some apt packages failed"
fi

# ---------------------------------------------------------------------------
log "2/9 Neovim (prebuilt 0.11+)"
if ! have nvim || ! nvim --version | head -1 | grep -qE 'v0\.(1[1-9]|[2-9][0-9])'; then
  fetch "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz" /tmp/nvim.tar.gz \
    && $SUDO rm -rf /opt/nvim \
    && $SUDO tar -C /opt -xzf /tmp/nvim.tar.gz \
    && $SUDO mv /opt/nvim-linux-x86_64 /opt/nvim \
    && $SUDO ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim \
    && log "  nvim $(nvim --version | head -1)" \
    || warn "neovim install failed"
else
  log "  nvim present: $(nvim --version | head -1)"
fi

# ---------------------------------------------------------------------------
log "3/9 jujutsu (jj) — latest release"
if ! have jj; then
  # /releases/latest redirects to the tagged version; scrape the tag from it.
  JJ_TAG="$(curl -fsSL -o /dev/null -w '%{url_effective}' \
            https://github.com/jj-vcs/jj/releases/latest 2>/dev/null | grep -oE 'v[0-9.]+$')"
  if [ -n "${JJ_TAG:-}" ]; then
    fetch "https://github.com/jj-vcs/jj/releases/download/${JJ_TAG}/jj-${JJ_TAG}-x86_64-unknown-linux-musl.tar.gz" /tmp/jj.tar.gz \
      && tar -C /tmp -xzf /tmp/jj.tar.gz jj \
      && $SUDO mv /tmp/jj /usr/local/bin/jj && $SUDO chmod +x /usr/local/bin/jj \
      && log "  $(jj --version)" \
      || warn "jj install failed"
  else
    warn "could not resolve latest jj tag"
  fi
else
  log "  jj present: $(jj --version)"
fi

# ---------------------------------------------------------------------------
log "4/9 busted + nlua (test runner inside the nvim Lua runtime)"
if [ -x "$HOME/.luarocks/bin/busted" ] && [ -x "$HOME/.luarocks/bin/nlua" ]; then
  log "  busted + nlua present"
else
  luarocks install --local busted >/dev/null 2>&1 && log "  busted installed"  || warn "busted failed"
  luarocks install --local nlua   >/dev/null 2>&1 && log "  nlua installed"    || warn "nlua failed"
fi

# ---------------------------------------------------------------------------
log "5/9 stylua (formatter)"
if ! have stylua; then
  fetch "https://github.com/JohnnyMorganz/StyLua/releases/latest/download/stylua-linux-x86_64.zip" /tmp/stylua.zip \
    && unzip -oq /tmp/stylua.zip -d /tmp/stylua.d \
    && $SUDO mv /tmp/stylua.d/stylua /usr/local/bin/ && $SUDO chmod +x /usr/local/bin/stylua \
    && log "  $(stylua --version)" || warn "stylua install failed"
else
  log "  stylua present: $(stylua --version)"
fi

# ---------------------------------------------------------------------------
log "6/9 ttyd (vhs dependency)"
if ! have ttyd; then
  fetch "https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.x86_64" /tmp/ttyd \
    && $SUDO mv /tmp/ttyd /usr/local/bin/ttyd && $SUDO chmod +x /usr/local/bin/ttyd \
    && log "  $(ttyd --version 2>&1 | head -1)" || warn "ttyd install failed"
else
  log "  ttyd present"
fi

# ---------------------------------------------------------------------------
log "7/9 vhs (terminal -> PNG/GIF)"
if ! have vhs; then
  VHS_TAG="$(curl -fsSL -o /dev/null -w '%{url_effective}' \
             https://github.com/charmbracelet/vhs/releases/latest 2>/dev/null | grep -oE 'v[0-9.]+$')"
  VHS_VER="${VHS_TAG#v}"
  fetch "https://github.com/charmbracelet/vhs/releases/download/${VHS_TAG}/vhs_${VHS_VER}_Linux_x86_64.tar.gz" /tmp/vhs.tar.gz \
    && tar -C /tmp -xzf /tmp/vhs.tar.gz \
    && $SUDO find /tmp -maxdepth 2 -name vhs -type f -path '*vhs*' -exec mv {} /usr/local/bin/vhs \; \
    && $SUDO chmod +x /usr/local/bin/vhs \
    && log "  $(vhs --version 2>&1 | head -1)" || warn "vhs install failed"
else
  log "  vhs present: $(vhs --version 2>&1 | head -1)"
fi

# ---------------------------------------------------------------------------
log "8/9 chromium shim for vhs (headless, root-safe)"
# vhs renders via go-rod (headless Chromium). As root, in a minimal container,
# Chromium needs --no-sandbox AND --no-zygote or it hangs forever. go-rod finds
# a browser named 'chromium' on PATH, so we expose a flag-injecting wrapper.
CHROME_BIN="$(find /opt/pw-browsers -maxdepth 3 -name chrome -type f 2>/dev/null | head -1)"
if [ -n "${CHROME_BIN:-}" ]; then
  $SUDO tee /usr/local/bin/chromium >/dev/null <<EOF
#!/usr/bin/env bash
# go-rod/vhs browser shim — container-friendly headless flags for root.
exec "${CHROME_BIN}" --no-sandbox --no-zygote --disable-gpu --disable-dev-shm-usage "\$@"
EOF
  $SUDO chmod +x /usr/local/bin/chromium
  log "  chromium shim -> ${CHROME_BIN}"
else
  warn "no pre-installed chromium found under /opt/pw-browsers; vhs screenshots unavailable"
fi

# ---------------------------------------------------------------------------
log "9/9 environment snippet"
# busted needs the luarocks --local tree on LUA_PATH/LUA_CPATH. Emit a snippet
# that test/screenshot scripts (and an interactive shell) can source.
ENVFILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/dev-env.sh"
{
  echo '# sourced by scripts/test.sh and scripts/screenshot.sh — generated by bootstrap'
  echo 'export PATH="$HOME/.luarocks/bin:/usr/local/bin:$PATH"'
  echo 'eval "$(luarocks path --local 2>/dev/null)"'
} > "$ENVFILE"
log "  wrote $ENVFILE"

log "done. nvim=$(have nvim && echo y || echo n) jj=$(have jj && echo y || echo n) busted=$([ -x "$HOME/.luarocks/bin/busted" ] && echo y || echo n) vhs=$(have vhs && echo y || echo n)"
