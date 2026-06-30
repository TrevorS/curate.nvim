# curate.nvim — Gated Execution Workflow

How a phase from [`PLAN.md`](PLAN.md) goes from "planned" to "done." The point of
gates is that **"done" is mechanical, not a judgement call**: a phase ships only
when a fixed set of checks passes, and the same checks run every phase.

## The dev environment (provision once)

Everything is provisioned by one idempotent script (also wired as a SessionStart
hook, so a fresh Claude-Code-on-web container self-heals):

```sh
bash scripts/bootstrap-dev-env.sh
```

It installs Neovim 0.11+, jj (latest), busted + nlua, luacheck, stylua, and VHS
(+ ttyd/ffmpeg + a root-safe headless-Chromium shim). Re-running is a fast no-op
when everything is present. Why a script and not Docker: this environment exposes
a docker CLI but no reachable daemon, so a provisioning script is the portable,
reproducible path.

## The per-phase loop

```
   ┌─────────────────────────────────────────────────────────┐
   │ 1. implement   write lua/ + plugin/ for the phase         │
   │ 2. format      make format        (stylua)                │
   │ 3. lint+test   make test          ← the GATE              │
   │ 4. screenshot  make screenshots   (or one tape)           │
   │ 5. eyeball     Read the PNG; confirm it matches intent    │
   │ 6. commit      one commit per phase, gate green           │
   └─────────────────────────────────────────────────────────┘
```

No step is skipped. A red gate blocks the commit; a failing screenshot is a red
gate even if tests pass.

## The GATE (`make test`)

`scripts/test.sh` runs three things, all of which must pass:

1. **`luacheck`** — 0 warnings, 0 errors across `lua/ plugin/ spec/`.
2. **`busted --lua=nlua`** — unit + integration specs run **inside Neovim's Lua
   runtime** (via `nlua`), so `vim.system` / `vim.api` / real `jj` are live, not
   mocked.
3. **`nvim -l spec/e2e/*.lua`** — end-to-end scripts that need a real RPC server
   loop (the diff-editor: jj → shim → nvim → write-back). `nlua` can't pump
   incoming RPC during `vim.wait`, so these run as standalone `nvim -l`.

`make check` (`stylua --check` + `luacheck`) is the fast pre-commit subset.

### Why two test harnesses

| harness | runs | use for |
|---|---|---|
| `busted --lua=nlua` | all `spec/*_spec.lua` | pure logic + jj-backed integration |
| `nvim -l spec/e2e/*.lua` | the diff-editor handshake | anything needing a live RPC server loop |

The split is not incidental: the wedge's correctness depends on a real
remote-wait, which only a full `nvim -l` (not the restricted nlua nvim) can drive.

## Screenshots as a gate artifact

Visual surfaces (status, diff-editor, op-log) have VHS tapes in `scripts/tape/`.
`make screenshots` regenerates PNGs/GIFs from the **real plugin** against a
throwaway jj repo (`scripts/demo-repo.sh`) — never a mock. The reviewer (you or
the agent) reads the PNG and confirms it matches the design before the phase
commits. A surface with no passing screenshot is not done.

```sh
make screenshots                              # all tapes
bash scripts/screenshot.sh scripts/tape/status.tape   # one tape
```

## Adding a new phase (e.g. P4 merge-editor)

1. Add the phase to `PLAN.md` with its **GATE** stated up front (the assertions
   that will prove it).
2. Implement under `lua/curate/…`; keep data/ui/views/actions separation.
3. Write the spec first if it's testable logic (e.g. a conflict-hunk engine) so
   the gate exists before the code.
4. For anything driving a jj subprocess that calls back into nvim, add an
   `spec/e2e/*.lua` script (it auto-joins the gate via `scripts/test.sh`).
5. Add a VHS tape if it's a visible surface.
6. Run the loop above; commit when the gate is green.

## Invariants the gate protects

- **No shell.** `luacheck` + review reject `os.execute`/`sh -c`/string-built jj.
- **change-id anchoring.** Buffers/marks/ops key on `change_id`, never `commit_id`.
- **Append-only recovery.** `op restore` writes a new op; tests assert the op
  count grows, never shrinks.
- **The wedge is real.** The e2e proves selective hunk write-back against actual
  jj, not a stub — so the differentiator can't silently regress.
