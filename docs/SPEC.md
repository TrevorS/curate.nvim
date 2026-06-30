# curate.nvim — v1 Specification

Distilled from the design documents in [`../project/`](../project/) (the
`curate.nvim Lua Architecture` and `curate.nvim v1 Spec` HTML prototypes) into a
build-ready, in-repo spec. This is the contract the implementation satisfies.

> **Purpose:** jj's working copy is already a commit; curate is the one tool for
> turning it into the commit you meant. Be the best in the world at **moving
> changes into the right commit** — and nothing else.

## 1. The loop

Four verbs. ROUTE is the expertise; everything else exists to serve it.

| verb | surfaces | jj commands |
|---|---|---|
| **SEE** | status home (foldable files→hunks tree + log graph), standalone log | `status` `log` |
| **ROUTE ★** | absorb · squash (whole/interactive/into-mark) · split — the last two via the **native diff-editor** | `absorb` `squash [-i]` `split -i` `diffedit` `restore` |
| **NAME** | describe buffer, commit (describe+new), new | `describe` `commit` `new` |
| **TRUST** | op-log time machine (restore/walk/diff), undo, evolog | `op log` `op restore` `undo` `evolog` |

## 2. Data layer (P0) — three non-negotiables

1. **EXEC.** Argv arrays via `vim.system({"jj", …})`. Never a shell, never
   string-built commands. Async with callbacks on the main loop
   (`vim.schedule_wrap`); a sync variant for setup/health only.
2. **IDENTITY.** Anchor everything — buffers, marks, op refs — on `change_id`.
   Never `commit_id`, never a bookmark. Survives rewrites mid-session.
3. **READ MODEL.** One `jj log -T` template, control-byte separated, parsed into
   typed records. Never scrape graph glyphs. Graph topology comes from the
   `parents` field, laid out by us.

The one read query (field order **is** the contract):

```
change_id ⟂ commit_id.short(8) ⟂ author.email() ⟂ committer.timestamp().ago()
  ⟂ description.first_line() ⟂ parents.map(|c| c.change_id())
  ⟂ flags[conflict C, divergent D, immutable I, current @, empty E]   ␞
```

`⟂` = `\x1f` (US), `␞` = `\x1e` (RS) — bytes that cannot occur in the data.

> **Deviation from the design:** the prototype used `\u{1f}` in the template
> literal; jj 0.42 rejects that escape. The implementation uses the verified
> `\x1f`/`\x1e` byte escapes.

## 3. The keymap (the contract)

Lower-case = safe · **UPPER-case = rewrites history** · `.` repeats the last
rewriting gesture · counts apply. Full table in
[`../curate.nvim/README.md`](../curate.nvim/README.md#keymap-the-contract) and
`:help curate-keymaps`. The keymap lives as **data** in `lua/curate/keymap.lua`,
feeding ftplugin maps, which-key labels, and the generated cheatsheet from one
source of truth.

## 4. ROUTE ★ — the diff-editor protocol (the wedge)

curate registers itself as jj's `ui.diff-editor`, so `split -i` / `squash -i` /
`diffedit` open a native nvim hunk-selection buffer. The contract:

1. jj materialises `$left` (before) and `$right` (after, writable) directories,
   invokes our program, and **blocks**.
2. curate opens the hunk buffer diffing `$left ↔ $right`. Every hunk starts
   **selected** (= included in the result).
3. The user toggles hunks off. On `<CR>`, curate reconstructs each `$right` file
   from **only the selected hunks** and writes it back. On `q`, it aborts.
4. curate exits 0 → jj snapshots `$right` and records the diff. Non-zero → jj
   cancels cleanly.

The link between jj (which blocks on a subprocess) and the **running** nvim is an
nvr-style wait-shim: jj spawns `curate-diff-shim`, which asks the running nvim
(via `$CURATE_SERVER`) to open the buffer, then parks polling a result file the
editor writes the exit code to. No temp git repo, no `intent-to-add`.

**One buffer, four modes** (only the label + target semantics change): SPLIT,
SQUASH-i, DIFFEDIT, RESTORE.

**v1 edge cases:** zero hunks selected → abort cleanly (no empty change); binary
file → file-level toggle only; immutable target → confirm before launch;
partial-line selection → out of v1 (the hunk is the atom).

## 5. TRUST — the op-log time machine

Whole-repo, reversible, **append-only**: `op restore` writes a NEW op, so forward
history is never lost. `<CR>` restores (confirmed), `=` shows the op's diff,
`g-`/`g+` walk undo/redo, `u` is global undo. This is the surface that makes
ROUTE fearless.

## 6. Scope, drawn on purpose

- **CORE (the experts):** absorb · squash/split hunk-routing · the status diff
  tree · describe/commit/new · op-log + undo.
- **SUPPORTING (ship it, don't innovate):** log home · a focused rebase gesture ·
  bookmark · git push/fetch.
- **OUT (v1):** interactive rebase graph-surgery → jjui; revset IDE / forge /
  pickers → jj.nvim; ambient gutter signs → vcsigns/vcmarkers.

## 7. Ship gate

**v1 = P0 → P3 + narrow P6.** At that point curate does one thing better than
anything in the ecosystem: move changes into the right commit. P4 (reshape +
merge-editor), P5 (full sync), P7 (inspect + power surface) are later chapters.
See [`PLAN.md`](PLAN.md).
