# curate.nvim — P9 · sticky args everywhere (sketch)

P8 built the sticky-arg mechanism into the transient engine and used it in one
place (the push menu's `--allow-new`). P9 **plumbs it through every menu that
wraps a flag-bearing jj verb**, and completes the engine with **value args**
(magit's `=thing` — a flag that carries a prompted value). The result: the
menus read like magit transients — a row of toggleable `-` args above the
actions, and whatever you toggle rides along with the action you pick.

> **Scope guardrail.** Only *menus* gain args, and only for flags that are valid
> for **every** action in that menu (so a toggle can't produce an invalid argv).
> The instant single-key rewrites (`s` squash, `n` new, `D` abandon) stay
> instant — their flags are niche and a popup would tax the 80% path. This is
> the P8 rule again: a popup only earns its keystroke when the flags do.

Stacked on `claude/curate-magit-grammar` (#4).

---

## 1. Where sticky args belong (the audit)

| menu | key | jj verb(s) | every-action flags → sticky args |
|---|---|---|---|
| **fetch/pull** | `f` | `git fetch` (+ pull = fetch then rebase) | `-a` `--all-remotes` |
| **push** | `P` | `git push` | `-d` `--dry-run` (shipped in #4) · **`=r` `--remote <name>`** (new value arg) |
| **rebase** | `r` | `rebase` (all 5 modes) | `-e` `--skip-emptied` · `-k` `--keep-divergent` |
| bookmark | `b` | `bookmark …` | — (name-driven, no useful toggles) |
| power | `Z` | duplicate/parallelize/fix/… | — (heterogeneous; no shared toggle) |

Only the network and rebase menus have flags that are (a) genuinely useful and
(b) valid across all of the menu's actions. Bookmark and power stay as they are.
(There is no `--allow-new` in jj 0.42 — pushing a named bookmark already allows
new; #4's push arg is `--dry-run`.)

## 2. Engine completion — value args

Today an `arg` item is a boolean (`{arg, flag, on}`). Add a **value** variant:

```lua
{ key = "r", arg = true, flag = "--remote", value = true, label = "remote" }
```

- Pressing its key prompts (`vim.ui.input`) for a value; the line shows
  `[=origin]` when set, `[ ]` when empty. Pressing again re-prompts; empty
  clears it.
- `flags()` contributes **two** argv entries for a set value arg (`--remote`,
  `origin`) and one for a set boolean (`--dry-run`).
- Order is preserved (args before actions, in item order), so the assembled
  argv is deterministic and testable.

## 3. The menu refactor (magit's F / P split)

P8's `f` was a *combined* fetch+pull+push menu. Split it the way magit splits
`F` (pull/fetch) and `P` (push), so each menu is single-purpose and its args are
valid for every action:

**`f` — fetch / pull** (all actions are fetch/pull → `--all-remotes` always valid)
```
- a  [ ] all remotes
  f      fetch
  u      pull  (fetch, then rebase @ onto trunk)
```
`pull` collapses to one action that honours `-a` (drops the old `U` duplicate);
`fetch` likewise (drops `F`).

**`P` — push** (all actions are pushes → the push flags always valid)
```
- d  [ ] dry run              (shipped in #4)
- r  [ ] remote =<name>       (new — value arg)
  p      push tracked bookmarks
  c      push this change as a new bookmark
  P      push all bookmarks
```

**`r` — rebase** (unchanged 5 actions; args ride along)
```
- e  [ ] skip emptied
- k  [ ] keep divergent
  d      onto (-s src -d dst, with descendants)
  r      only this revision
  b      whole branch
  A      insert after
  B      insert before
```

Each action's `run(flags)` appends the enabled flags to its argv — the actions
already build argv arrays, so this is a one-line `vim.list_extend` per action.

## 4. Keymap deltas (the contract)

No new keys — same `f` / `P` / `r`. Only labels change:

| view | key | label (was → now) |
|---|---|---|
| status, log | `f` | sync menu (fetch/pull/push) → **fetch/pull menu** |
| status, log | `P` | push menu (sticky `-n`) → **push menu** (sticky `-n`/`-d`/`=r`) |
| status, log | `r` | rebase (transient) → rebase (transient, sticky `-e`/`-k`) |

Push moves out of `f` into `P` (magit-faithful); `f` is now purely fetch/pull.

## 5. Tests & visuals

- **`transient_spec`** (extend): a value arg prompts, sets, and contributes
  `flag value` to `flags()`; clearing it removes both; boolean + value args
  compose in item order.
- **`p9_spec`** (integration, real jj): `push --dry-run` reports would-push
  without moving the remote; `rebase --skip-emptied` drops a commit that becomes
  empty; `fetch --all-remotes` is accepted. (Bare-remote fixture like
  `sync_spec`.)
- **GIFs/PNGs**: the `f`, `P` (toggling `-d`/`=r`), and `r` (toggling `-e`)
  menus under Catppuccin Mocha.

## 6. The PR (single, focused)

One gated commit-set on `claude/curate-sticky-args`, stacked on #4:

1. engine: value args in `ui/transient.lua` (+ `transient_spec`).
2. menus: `f` fetch/pull split, `P` push args, `r` rebase args; keymap labels.
3. docs: README keymap + `:help`; this sketch; `PLAN.md` P9.

- **GATE:** `make test` green; `transient_spec` proves value-arg composition;
  `p9_spec` proves `--dry-run`/`--skip-emptied`/`--all-remotes` reach jj; the
  three menu screenshots regenerate.

## 7. Out of scope (on purpose)

- Args on the instant rewrites (`s`/`n`/`D`) — the fast path stays fast; revisit
  only if a specific flag proves high-frequency.
- Persisting arg state across invocations (magit's "set as default") — every
  menu opens with args off; a saved-defaults layer is a separate decision.
- Free-form "any flag" entry — curate exposes *curated* args, not a jj CLI box.
