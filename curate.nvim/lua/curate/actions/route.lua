-- actions/route.lua — ROUTE ★: the expertise. absorb · squash · split, the
-- last two via the native diff-editor. Launching jj with curate registered as
-- ui.diff-editor is what makes us jj's diff editor.

local jj = require("curate.jj")
local util = require("curate.actions.util")
local config = require("curate.config")

local M = {}

--- Resolve the wait-shim path on the runtimepath.
---@return string|nil
local function shim_path()
  local hits = vim.api.nvim_get_runtime_file("bin/curate-diff-shim", false)
  return hits[1]
end

--- Ensure this nvim has an RPC server the shim can reach; return its address.
---@return string
local function ensure_server()
  if vim.v.servername ~= nil and vim.v.servername ~= "" then
    return vim.v.servername
  end
  -- Headless or no server yet — start one (returns its address).
  return vim.fn.serverstart()
end

--- Build the --config flags that point jj's diff-editor at our shim.
---@param shim string
---@return string[]
local function diff_editor_config(shim)
  local name = config.options.diff_editor_name or "curate"
  return {
    "--config",
    "ui.diff-editor=" .. name,
    "--config",
    ("merge-tools.%s.program=%s"):format(name, shim),
    "--config",
    ('merge-tools.%s.edit-args=["$left","$right"]'):format(name),
    -- jj expects the tool to edit $right in place (not produce a merged file).
    "--config",
    ("merge-tools.%s.merge-tool-edits-conflict-markers=false"):format(name),
    -- Suppress jj's text-editor prompt (e.g. split's description editor): naming
    -- is a separate `d` gesture in the NAME loop, so a no-op editor keeps the
    -- hunk-routing gesture self-contained and non-blocking. Array form so jj
    -- parses it as a command (a bare `true` would be a TOML boolean and error).
    "--config",
    'ui.editor=["true"]',
  }
end

--- Build the --config flags that point jj's merge-editor (jj resolve) at our
--- shim. Same tool program, different arg contract: base/left/right/output.
---@param shim string
---@return string[]
local function merge_editor_config(shim)
  local name = config.options.diff_editor_name or "curate"
  return {
    "--config",
    "ui.merge-editor=" .. name,
    "--config",
    ("merge-tools.%s.program=%s"):format(name, shim),
    "--config",
    ('merge-tools.%s.merge-args=["$base","$left","$right","$output"]'):format(name),
    -- We write resolved content (no jj conflict markers) into $output.
    "--config",
    ("merge-tools.%s.merge-tool-edits-conflict-markers=false"):format(name),
  }
end

--- Launch an interactive jj command through the curate diff-editor.
---@param base_args string[]   e.g. { "split", "-r", "@" } or { "squash", "-i" }
---@param mode string          split | squash-i | diffedit | restore
local function launch(base_args, mode)
  local shim = shim_path()
  if not shim then
    vim.notify("curate: diff-editor shim not found on runtimepath", vim.log.levels.ERROR)
    return
  end
  local server = ensure_server()
  local args = vim.list_extend(vim.deepcopy(base_args), diff_editor_config(shim))
  jj.runner.spawn(args, {
    cwd = jj.cwd(),
    env = { CURATE_SERVER = server, CURATE_MODE = mode },
  }, function(r)
    if r.code ~= 0 and r.stderr and r.stderr ~= "" then
      -- Non-zero is expected on abort; only surface genuine errors.
      if not r.stderr:lower():find("cancel") then
        vim.notify("curate: " .. r.stderr, vim.log.levels.WARN)
      end
    end
    util.refresh_all()
  end)
end

--- x — split the change under the cursor (or @) interactively by hunk.
function M.split_interactive()
  local id = util.cursor_change_id() or "@"
  launch({ "split", "-r", id }, "split")
end

--- S — squash interactively: selected hunks move from @ into its parent.
function M.squash_interactive()
  launch({ "squash", "-i" }, "squash-i")
end

--- = (interactive) — restore selected hunks from the parent (diffedit-style).
function M.restore_interactive()
  launch({ "diffedit", "-r", "@" }, "diffedit")
end

--- R — resolve conflicts in the change under the cursor (or @) interactively,
--- 3-way, through the curate merge-editor. jj invokes the tool once per
--- conflicted file; each opens its own merge buffer in sequence.
function M.resolve()
  local shim = shim_path()
  if not shim then
    vim.notify("curate: merge-editor shim not found on runtimepath", vim.log.levels.ERROR)
    return
  end
  local id = util.cursor_change_id() or "@"
  local server = ensure_server()
  local args = vim.list_extend({ "resolve", "-r", id }, merge_editor_config(shim))
  jj.runner.spawn(args, {
    cwd = jj.cwd(),
    env = { CURATE_SERVER = server, CURATE_MODE = "merge" },
  }, function(r)
    if r.code ~= 0 and r.stderr and r.stderr ~= "" then
      local low = r.stderr:lower()
      if not (low:find("cancel") or low:find("no conflicts")) then
        vim.notify("curate: " .. r.stderr, vim.log.levels.WARN)
      end
    end
    util.refresh_all()
  end)
end

-- ── absorb ──

--- A — absorb @'s changes into the closest mutable ancestor that last touched
--- each line. jj has no dry-run, so this is honest apply-and-undo: it runs as
--- one op and `u` reverts the whole fan-out. We report what landed where.
function M.absorb()
  jj.run({ "absorb" }, function(r)
    if r.code ~= 0 then
      vim.notify(
        "curate: absorb: " .. (r.stderr ~= "" and r.stderr or "nothing to absorb"),
        vim.log.levels.WARN
      )
    else
      -- jj prints "Absorbed changes into N revisions:"; surface its summary line.
      local summary = (r.stdout .. r.stderr):match("Absorbed[^\n]*") or "absorbed"
      vim.notify("curate: " .. summary .. "  (u to undo)", vim.log.levels.INFO)
    end
    util.refresh_all()
  end)
end

-- ── non-interactive squash (the 80% case) ──

--- s — squash @ wholesale into its parent (or into a marked target).
function M.squash()
  local mark = require("curate.actions.reshape").marked()
  local args = { "squash" }
  if mark then
    vim.list_extend(args, { "--into", mark })
  end
  util.mutate(jj, args, mark and ("squashed into " .. mark:sub(1, 8)) or "squashed into parent")
end

--- = — restore the file/hunk under the cursor from the parent.
function M.restore()
  local t = util.cursor_target()
  if t and t.type == "file" then
    util.mutate(jj, { "restore", t.file.path }, "restored " .. t.file.path)
  elseif t and t.type == "hunk" then
    -- Hunk-level restore goes through the interactive diffeditor.
    M.restore_interactive()
  else
    util.mutate(jj, { "restore" }, "restored working copy")
  end
end

--- Abandon the change under the cursor (or @), rebasing descendants onto its
--- parent. Guarded like the other rewrites; abandoning @ is recoverable (jj
--- gives a fresh empty @, `u` undoes it) but surprising, so confirm it. `flags`
--- are sticky args from the abandon menu (--restore-descendants / …).
---@param flags string[]|nil
function M.abandon(flags)
  local t = util.cursor_target()
  local change = t and t.change
  local id = (change and change.id) or "@"
  local is_current = (not change) or change.flags.current
  local function run()
    util.guard_immutable(t, "abandon", function()
      local args = vim.list_extend({ "abandon", "-r", id }, flags or {})
      util.mutate(jj, args, "abandoned " .. id:sub(1, 8) .. "  (u to undo)")
    end)
  end
  if is_current then
    vim.ui.select({ "yes", "no" }, { prompt = "abandon the working-copy change @?" }, function(c)
      if c == "yes" then
        run()
      end
    end)
  else
    run()
  end
end

--- k — the abandon transient: sticky args over the abandon action. Low-frequency
--- verb, so the extra keystroke is cheap and the flags are worth surfacing.
function M.abandon_menu()
  require("curate.ui.transient").open({
    title = "abandon",
    items = {
      {
        key = "d",
        arg = true,
        flag = "--restore-descendants",
        label = "restore descendants (don't rebase them)",
      },
      { key = "b", arg = true, flag = "--retain-bookmarks", label = "retain bookmarks" },
      { key = "k", label = "abandon the change", run = M.abandon },
    },
  })
end

return M
