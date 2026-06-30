# curate.nvim — workspace

This repo holds **curate.nvim**, a focused Jujutsu (jj) frontend for Neovim, built from a Claude Design handoff bundle.

> jj's working copy is already a commit; **curate** is the one tool for turning it into the commit you meant. SEE → ROUTE → NAME → TRUST, with a native hunk-level diff-editor as the hero.

## Layout

| path | what |
|---|---|
| [`curate.nvim/`](curate.nvim/) | **the plugin** — Lua source, tests, docs (`make test`) |
| [`scripts/`](scripts/) | dev-env bootstrap, test runner, VHS screenshot tooling |
| [`screenshots/`](screenshots/) | VHS captures of the real plugin (status, diff-editor, op-log) |
| [`project/`](project/) | the original design documents (HTML prototypes) |
| [`docs/DESIGN_HANDOFF.md`](docs/DESIGN_HANDOFF.md) | the original Claude Design handoff instructions |
| [`chats/`](chats/) | the design conversation that produced the spec |

Start with [`curate.nvim/README.md`](curate.nvim/README.md).

## Quick start (development)

The plugin needs Neovim 0.11+, jj, and a small Lua toolchain. One idempotent script provisions all of it (and is wired as a SessionStart hook for Claude Code on the web):

```sh
bash scripts/bootstrap-dev-env.sh    # nvim, jj, busted+nlua, luacheck, stylua, vhs
cd curate.nvim && make test          # luacheck + busted (nlua) + e2e diff-editor
```

### Tooling provisioned

| tool | purpose |
|---|---|
| Neovim 0.11+ | runtime (the design targets modern nvim APIs) |
| jj (latest) | the VCS the plugin drives |
| busted + nlua | tests **inside Neovim's Lua runtime** (real `vim` API) |
| luacheck / stylua | lint / format |
| VHS + ttyd + ffmpeg | terminal → PNG/GIF screenshots of the live plugin |
| tmux | driving nvim headlessly for capture/debug |

> Docker is intentionally not used: this environment exposes a docker CLI but no
> reachable daemon, so a reproducible provisioning script is the portable path.

## Design → implementation

The design medium was HTML, but the primary design (`curate.nvim Lua Architecture.dc.html`) is itself a **Lua module-tree sketch** — so "implementing the design" meant building the actual plugin it describes. The module tree, the `vim.system` runner, the template parser, the View base, the extmark render path, and the nvr-style diff-editor handshake all map 1:1 to the design. See `curate.nvim/README.md` for the mapping.

One deviation worth noting: the design's `jj log` template used the `\u{1f}` escape, which jj 0.42 rejects — the implementation uses the verified `\x1f`/`\x1e` byte escapes instead.
