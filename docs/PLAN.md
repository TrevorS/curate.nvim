# curate.nvim — Phased Build Plan (with gates)

Ordered by dependency and leverage, not by where surfaces sit. Each phase names
what it **delivers**, what it's **gated on**, and the **GATE** that must pass
before it's considered done. The gate is mechanical and identical in shape every
phase, so "done" is never a judgement call. See [`WORKFLOW.md`](WORKFLOW.md) for
how to run a gate.

**Status legend:** ✅ shipped · ◻ planned (post-v1).

---

## ✅ P0 · Foundation — the data layer (no UI)

- **Delivers:** `jj/runner.lua` (argv `vim.system`, async+sync+raw), `jj/template.lua`
  (the §2 read query + `\x1f`/`\x1e` parse → typed model), `jj/model.lua` (LuaCATS
  `Change`/`Op`), `jj/diff.lua` (git-diff parser), `jj/revset.lua`, `config.lua`.
- **Gated on:** nothing (first).
- **GATE:** `make check` clean; `template_spec` parses a real repo into Change
  records and survives a mid-session rewrite; diff parser splits files/hunks with
  correct add/remove counts. **→ met (6 tests).**

## ✅ ui · Mechanism (view-agnostic)

- **Delivers:** `ui/view.lua` (scratch buffer + ns + filetype + debounced
  refresh, singleton registry), `ui/render.lua` (row-builder → extmark spans),
  `ui/tree.lua` (files→hunks fold model), `ui/decor.lua` (decoration provider,
  ephemeral live highlight), `ui/transient.lua`, `ui/highlights.lua`.
- **Gated on:** P0.
- **GATE:** `make check` clean; `ui_spec` proves the row-builder column math, tree
  flattening + fold-state carry, and the View lifecycle (scratch buf, filetype,
  singleton focus). **→ met (4 tests).**

## ✅ P1 · SEE + NAME — the home

- **Delivers:** `views/status.lua` (@ header + foldable diff tree + log graph),
  `views/log.lua`, `views/describe.lua` (`:w` applies), `actions/name.lua`
  (describe/commit/new), `actions/trust.lua` (undo).
- **Gated on:** P0, ui.
- **GATE:** `make test`; `status_spec` renders @/diff/log against a live repo,
  `new` adds a change, `undo` reverts; screenshot `status-home.png` looks right.
  **→ met (3 integration tests + screenshot).**

## ✅ P2 · ROUTE ★ — the diff-editor (the wedge)

- **Delivers:** `diffeditor/hunks.lua` (pure LCS hunk engine + selective apply),
  `diffeditor/fs.lua`, `views/diffeditor.lua` (hunk buffer, 4 modes, write-back,
  edge cases), `diffeditor/rpc.lua` (server entry), `bin/curate-diff-shim`
  (nvr-style wait client), `actions/route.lua` (launchers).
- **Gated on:** P0, ui.
- **GATE:** `make test`; the **e2e** drives a real `jj split -i` through the shim
  into nvim, selects one of two hunks, and asserts the first commit holds exactly
  that hunk; abort leaves the repo unchanged; screenshot `diffeditor-open.png`.
  **→ met (8 hunk-engine unit tests + full e2e + screenshot).**

## ✅ P3 · ROUTE + TRUST — absorb & the time machine

- **Delivers:** `actions/route.lua` absorb + squash (s/S/m→s), `views/oplog.lua`
  (restore/walk/diff), `views/evolog.lua`, `actions/trust.lua` (op_restore, redo).
- **Gated on:** P1, P2.
- **GATE:** `make test`; absorb empties @ into the owning ancestor; squash folds @
  into its parent; op-log renders and restore is append-only (op count grows);
  screenshot `oplog.png`. **→ met (3 integration tests + screenshot).**

## ✅ P6 (narrow) · Grammar + supporting

- **Delivers:** `keymap.lua` registry (ftplugin maps + which-key + cheatsheet),
  dot-repeat, statusline-able labels; `actions/sync.lua` (bookmark/push/fetch),
  `actions/reshape.lua` (mark/rebase), `views/file.lua` (`curate://` buffers via
  cp-as-tool), `views/process.lua`, `health.lua`, `plugin/curate.lua`, `init.lua`.
- **Gated on:** P1–P3.
- **GATE:** `make test`; `keymap_spec` proves every action string parses
  (underscore-aware) and P0–P2 actions resolve; `p6_spec` round-trips a
  `curate://` file edit and sets a bookmark; `:checkhealth curate` all ✅.
  **→ met (4 tests + checkhealth).**

---

### Ship gate — **v1 = P0 → P3 + narrow P6** ✅ (all green)

`make test` → luacheck 0 warnings, 31 busted + e2e pass; `make check` clean.

---

## ◻ P4 · Reshape (post-v1)

- **Delivers:** richer rebase transient (insert-before/after), the **merge-editor**
  protocol (3-way conflict resolution reusing the diff-editor RPC), `R` resolve.
- **Gated on:** P2 (reuses the RPC handshake + hunk buffer).
- **GATE (planned):** e2e drives `jj resolve` through curate as `ui.merge-editor`;
  a conflicted change resolves to clean in-buffer; screenshot.

## ◻ P5 · Sync (post-v1)

- **Delivers:** full bookmark lifecycle (track/forget), push `--change`, fetch all
  remotes, a sync transient.
- **Gated on:** P6 supporting stubs.
- **GATE (planned):** integration against a local bare remote; push/fetch/tug
  round-trip.

## ◻ P7 · Inspect + power surface (post-v1)

- **Delivers:** revset workbench (live-recomputing query buffer), annotate/blame,
  the reserved-key power surface (`workspace`/`fix`/`duplicate`/`parallelize`).
- **Gated on:** P0 (revset typing), P1 (log).
- **GATE (planned):** revset edits recompute the log live; annotate scroll-binds.

> The ambient gutter layer is explicitly **not** a phase — defer to vcsigns.
