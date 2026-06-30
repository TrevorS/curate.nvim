# Contributing to curate.nvim

Thanks for helping curate the working copy. This project goes deep on one loop —
**moving changes into the right commit** — so contributions are judged against
that focus as much as correctness. See [`docs/SPEC.md`](docs/SPEC.md) for the
design intent and [`docs/PLAN.md`](docs/PLAN.md) for the phased roadmap.

## Setup

The whole toolchain (Neovim 0.11+, jj, busted + nlua, luacheck, stylua, VHS) is
provisioned by one idempotent script — the same one the CI job and the web
SessionStart hook run:

```sh
bash scripts/bootstrap-dev-env.sh
```

Re-run it any time; it fast-paths when everything is present.

## The gate

Every change must pass the same mechanical gate locally and in CI:

```sh
make test    # luacheck (0 warnings) + busted (nlua, real vim API) + e2e
make check   # stylua --check + luacheck
make format  # stylua write (run before committing)
```

- **busted** specs run *inside* Neovim's Lua runtime via `nlua`, so `vim.system`
  and `vim.api` are live. Put pure logic behind testable functions (see
  `diffeditor/hunks.lua`, `diffeditor/merge3.lua`).
- The **e2e** scripts in `spec/e2e/` drive a real `jj` through the RPC shim and
  need a server loop `nlua` can't pump, so they run as standalone `nvim -l`
  scripts (the runner picks up `spec/e2e/*.lua` automatically).
- Surfaces that change visibly should regenerate their VHS capture:
  `make screenshots` (or `scripts/screenshot.sh scripts/tape/<name>.tape`).

CI (`.github/workflows/ci.yml`) runs `bootstrap → make test → stylua --check` on
every push and PR.

## Architecture rules (keep the layers honest)

- **Data never knows about windows.** `jj/` returns typed models; it never opens
  buffers.
- **Views never shell out.** Surfaces in `views/` render; they call `actions/`
  or `jj/` for data, never `vim.system` directly.
- **Everything mutating funnels through `actions/`**, so undo/refresh/dot-repeat
  stay consistent.
- The keymap is **data** in `lua/curate/keymap.lua` — one table feeds the
  ftplugin maps, which-key labels, and the generated cheatsheet. Add keys there,
  not ad hoc.

## Conventions

- Lower-case keys are safe; **UPPER-case keys rewrite history** (`rw = true` in
  the registry). Keep that contract.
- Match the surrounding comment density and naming; explain *why*, not *what*.
- Verify jj's real behavior before coding against it — jj's CLI contracts (diff/
  merge tool args, revset string-pattern defaults, template keywords) shift
  between releases. Probe, don't assume.

## Pull requests

Open PRs against `master`. Fill in the PR template (summary, changes, phase,
test plan). Keep PRs scoped to one phase or fix where possible.
