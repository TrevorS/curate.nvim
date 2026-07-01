# curate.nvim — P8 · magit-grade command grammar (sketch)

A design sketch for making the everyday jj verbs **great**, in the style of
[magit](https://magit.vc): one discoverable key per verb, transient popups with
sticky args for the verbs that take options, and consistent safety
(lower-case = safe · **UPPER = rewrites history** · confirm before touching
immutable). This is the **first PR in a stack** — it commits the plan; the
implementation lands in the follow-up PRs in §6.

> **Scope guardrail (unchanged).** curate is still "the one tool for moving
> changes into the right commit — and nothing else" ([SPEC §6](SPEC.md)). Every
> verb below is an *everyday* jj command a user already reaches for from the
> status home; none of it is forge, graph-surgery, or a revset IDE. If a verb
> would pull us toward those, it stays out.

---

## 1. Audit — where each verb stands today

`key` = current binding in [`keymap.lua`](../curate.nvim/lua/curate/keymap.lua);
`module` = the action fn. Verdict: ✅ solid · ⚠ polish · ✱ missing.

| # | verb | jj | today | magit parallel | verdict |
|---|---|---|---|---|---|
| 1 | **status** | `status` | status home (`:Curate`) | `magit-status` | ✅ |
| 2 | **log** | `log` | log view (`:Curate log`), `e` revset | `l` log popup | ⚠ add a log transient (revset presets, `-n`, `--all`) |
| 3 | **new** | `new` | `n` · `name.new` | — | ✅ |
| 4 | **describe** | `describe` | `d` · `name.describe` | `magit-commit` (msg) | ✅ |
| 5 | **commit** | `commit` | `c` · `name.commit` | `c` commit popup | ⚠ fold into a commit transient (describe / commit / amend@ / new) |
| 6 | **squash** | `squash [-i]` | `s`,`S` · `route.squash*` | (no direct analog) | ✅ |
| 7 | **diff** | `diff` | `=` / `<CR>` expand · diff-editor | `d` diff popup | ⚠ a "show diff" that reuses the read model |
| 8 | **op log** | `op log` | `o` · `trust.oplog` | `magit-reflog` | ✅ |
| 9 | **undo** | `undo` | `u` · `trust.undo` | `magit-reset`/reflog | ✅ |
| 10 | **git push** | `git push` | `f`→push · `sync.push*` | `P` push popup | ⚠ promote to a push transient w/ args |
| 11 | **branch** (bookmark) | `bookmark` | `b` · `sync.bookmark` | `b` branch popup | ✅ (already a transient) |
| 12 | **abandon** | `abandon` | — | `k` discard / `x` reset | ✱ **missing** |
| 13 | **git pull** | `git fetch` + rebase | `f`→fetch only | `F` pull popup | ✱ **missing** (fetch exists; no fetch-and-rebase) |
| 14 | **file untrack** | `file untrack` | — | `k` on an untracked/ignored file | ✱ **missing** |

**Takeaway:** 8 verbs are already solid; 3 need a magit-grade transient
(log/commit/diff/push polish, item-counted above), and **3 are net-new**
(abandon, pull, file untrack). No new *surfaces* are required — everything hangs
off the existing status/log views and the transient engine.

---

## 2. Gaps to close (net-new)

### 2.1 `abandon` — drop a change (⚠ rewrites)

`jj abandon -r <change>` deletes the change and rebases its descendants onto its
parent. It is the "kill this" verb magit spells `k`.

- **Key:** `k` (mnemonic "kill"; unbound today) in `curate-status` and
  `curate-log`. Marked `rw = true` so `.` repeats it and the cheatsheet flags it.
- **Module:** `actions/route.lua` → `M.abandon()` (abandon is a routing verb —
  it moves a change's *contents* to nowhere). Target = change under cursor, or
  `@`.
- **Safety:** route through `util.guard_immutable(target, "abandon", fn)` — the
  same confirm gate absorb/squash use — and confirm when abandoning `@` (you'd
  lose the working-copy change) via `vim.ui.select` yes/no.
- **jj:** `{ "abandon", "-r", id }`. Descendants reparent automatically.

### 2.2 `pull` — fetch, then rebase onto the updated remote (⚠ rewrites)

jj has no `pull`; the idiom is `git fetch` followed by a rebase of your work
onto the freshly-moved `trunk()`. magit's `F` in one gesture.

- **Where:** the existing sync transient (`f`), as two new items so the plain
  `fetch` stays available:
  - `u` — **pull** = `git fetch` → on success `rebase -b @ -d 'trunk()'`
    (rebases the current change's whole branch onto the new trunk).
  - `U` — **pull --all** = `git fetch --all-remotes` → same rebase.
- **Module:** `actions/sync.lua` → `M.pull()` chains `jj.run` (fetch) then
  `util.mutate` (rebase), so a fetch failure aborts before any rewrite.
- **Safety:** the rebase step is history-rewriting → confirm if `@`'s branch
  touches immutable changes; surface "already up to date" as a soft no-op.

### 2.3 `file untrack` — stop tracking a file

`jj file untrack <path>` removes a path from the working copy's tracked set
(the file must be ignored, else jj re-adds it — we hint this on error).

- **Key:** `K` on a **file node** in the status diff tree (`curate-status`).
  Upper-case because it changes what `@` records. `k` is taken by abandon at the
  change level; `K` reads as "untrack the file the cursor is on."
- **Module:** new `actions/files.lua` → `M.untrack()`, reading the file path
  from the status tree node under the cursor (`util.cursor_target()` already
  returns the node; extend it to expose `node.file.path`).
- **jj:** `{ "file", "untrack", path }`; on the "still tracked because not
  ignored" error, notify with the `.gitignore` hint rather than a raw stderr.
- **Companion:** `k` at a file node could offer *track* symmetrically later;
  out of this sketch to keep the surface minimal.

---

## 3. magit-grade polish (existing → great)

### 3.1 Complete the sticky-arg mechanism in the transient engine

[`ui/transient.lua`](../curate.nvim/lua/curate/ui/transient.lua) already models
an `arg` item (rendered with a `-` prefix) but notes *"sticky args are toggled
by callers that pass a stateful run"* — i.e. the toggle isn't wired. Finish it:

- An `arg` item holds `{ flag = "--all", on = false }`. Pressing its key toggles
  `on` and repaints the line (`[-]`/`[✓]`), the buffer staying open.
- Action items read the live arg state and append enabled flags to their argv.
- This is the one piece of real engine work; every verb transient below reuses
  it, so it's built once.

### 3.2 Verb transients (opt-in popups, not new surfaces)

Each is a `transient.open` spec — a few keys + args — opened from the status/log
home. They *wrap* existing actions; the bare single-key bindings stay for muscle
memory.

- **commit (`c`)** → `d` describe · `c` describe-and-new · `a` amend (re-describe
  `@`) · `n` new. (Collapses today's `c`/`d` into one discoverable popup.)
- **log (`l`)** → args `--all` `-n <count>` `-r <revset>`; actions: open log,
  open revset workbench. (Today `e` opens the workbench; `l` gives the popup.)
- **diff (`d` in the diff context)** → this change · `@` vs parent · against a
  marked change. Reuses `jj/diff.lua` + the read model.
- **push (`P`)** → args `--all` `--change` `<remote>`; actions: push tracked /
  this-change-as-bookmark / all. (Promotes today's `f`→push items to their own
  magit-style `P` popup with sticky args; `f` sync menu stays.)

> `rebase` (`r`) and `bookmark` (`b`) are **already** transients — they set the
> pattern these follow.

### 3.3 Consistency pass

- **Confirm gate:** every history-rewriting verb goes through
  `util.guard_immutable` (abandon/pull join absorb/squash/rebase). One code
  path, one prompt style.
- **Dot-repeat:** new `rw = true` verbs (abandon, pull) auto-participate in `.`
  via the existing `M._last` machinery — no extra code, just the flag.
- **One source of truth:** all new keys are rows in `keymap.lua`, so they flow to
  ftplugin maps, which-key labels, and the `?` cheatsheet for free.

---

## 4. Keymap deltas (the contract)

Lower = safe · **UPPER = rewrites / changes what `@` records**. New rows only:

| view | key | action | label | rw |
|---|---|---|---|---|
| status, log | `k` | `route.abandon` | abandon change | ⚠ |
| status (file node) | `K` | `files.untrack` | untrack file | ⚠ |
| status, log | `l` | `power.log` (transient) | log menu | |
| status, log | `c` | `name.commit_menu` (transient) | commit menu | |
| status, log | `P` | `sync.push_menu` (transient) | push menu | |
| sync transient | `u`/`U` | `sync.pull` / `pull_all` | pull (fetch + rebase) | ⚠ |

`c` today runs `name.commit` directly; it becomes the transient whose default
(`c`) is still commit — zero relearning, more discoverable.

---

## 5. Per-verb target behaviour (magit-faithful, jj-correct)

- **status** — home; `@` header + foldable files→hunks tree + log graph. *(done)*
- **log** — `l` popup → `jj log` view or revset workbench; args `--all`/`-n`/`-r`.
- **new** — `n` → `jj new` (child of the change under cursor or `@`). *(done)*
- **describe** — `d`/commit-menu → `jj describe` buffer, `:w` applies. *(done)*
- **commit** — `c` menu → describe `@` then `jj new` (= `jj commit`); `a` amend. *(done, folded into menu)*
- **squash** — `s`/`S` → `jj squash [-i]`; `m` then `s` squashes into a mark. *(done)*
- **diff** — `d`/`=` → git-diff of the change via `jj/diff.lua`; `<CR>` expands hunks. *(polish)*
- **op log** — `o` → `jj op log` time machine; `<CR>` restore (append-only). *(done)*
- **undo** — `u` → `jj undo`; `g-`/`g+` walk. *(done)*
- **git push** — `P` menu → `jj git push [--all|--change]`. *(polish)*
- **branch** — `b` menu → `jj bookmark set/tug/delete/forget/track/untrack/list`. *(done)*
- **abandon** — `k` → `jj abandon -r <id>` (guarded, confirm on `@`). *(new)*
- **git pull** — sync `u`/`U` → `jj git fetch` then `jj rebase -b @ -d trunk()`. *(new)*
- **file untrack** — `K` on a file node → `jj file untrack <path>` (ignore hint). *(new)*

---

## 6. Phasing — the PR stack (this branch first)

Stacked on `claude/curate-nvim-themes-lcoctn`. Each PR is one gated commit
([WORKFLOW.md](WORKFLOW.md): `make test` green + screenshot where a surface
changes).

1. **PR-1 (this): the sketch.** No code; agrees the grammar and keymap deltas.
2. **PR-2: net-new verbs.** `route.abandon`, `sync.pull`/`pull_all`,
   `actions/files.untrack`; keymap rows `k`/`K` and sync `u`/`U`.
   - **GATE:** integration specs — abandon drops a change and reparents its
     child; pull fetches then rebases onto a moved trunk (bare-remote fixture,
     like `sync_spec`); untrack removes a gitignored path from `jj status`.
     `keymap_spec` proves the new action strings resolve.
3. **PR-3: transient args + verb popups.** Finish the sticky-arg toggle in
   `ui/transient.lua`; add the `c`/`l`/`P` menus.
   - **GATE:** a `transient_spec` toggling an arg flips the assembled argv;
     `keymap_spec` covers the menu entries; refreshed `status` screenshot shows
     a popup with a `[✓]` arg.

Splitting net-new verbs (PR-2) from the transient engine (PR-3) keeps each PR
small, independently reviewable, and independently revertible.

---

## 7. What stays OUT (so the surface stays sharp)

Per [SPEC §6](SPEC.md): interactive rebase graph-surgery (→ jjui), a revset IDE
/ forge / PR pickers (→ jj.nvim), ambient gutter signs (→ vcsigns). "pull" is a
*fetch-then-rebase convenience*, not a merge/PR workflow; "abandon" and "untrack"
are single jj verbs, not a discard-hunks staging model. If a follow-up wants
partial-file untracking, remote management, or a rebase-todo editor, it is a new
scope decision, not this phase.
