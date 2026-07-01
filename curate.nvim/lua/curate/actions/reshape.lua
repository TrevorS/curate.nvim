-- actions/reshape.lua — C · reshape the graph: mark · rebase · resolve.
--
-- jj has no rebase-todo: you compose primitives and descendants auto-rebase. So
-- the gesture is "mark a source, pick a destination, rebase" — with the marked
-- destination live-highlighted via ui/decor.

local jj = require("curate.jj")
local util = require("curate.actions.util")
local decor = require("curate.ui.decor")

local M = {}

M._mark = nil ---@type string|nil

--- The currently marked change-id, if any.
---@return string|nil
function M.marked()
  return M._mark
end

--- m — mark the change under the cursor as the rebase source / squash target,
--- and light up the destination highlight as the cursor moves.
function M.mark()
  local t, view = util.cursor_target()
  if not (t and t.id) then
    return
  end
  M._mark = t.id
  if view then
    decor.set_dest(view.buf, t.id)
  end
  vim.notify("curate: marked " .. t.id:sub(1, 8), vim.log.levels.INFO)
end

--- r — open the rebase transient: source = marked change (or @), destination =
--- the change under the cursor. jj has no rebase-todo, so each entry is a
--- distinct primitive (onto / just-this-rev / whole-branch / insert around).
function M.rebase()
  local t, view = util.cursor_target()
  local dest = t and t.id
  if not dest then
    return
  end
  local source = M._mark or "@"

  -- `args` is the base rebase argv; `flags` are the sticky args toggled in the
  -- transient (--skip-emptied / --keep-divergent), appended to every mode.
  local function run(args, flags, label)
    util.guard_immutable(t, "rebase", function()
      util.mutate(jj, vim.list_extend(args, flags or {}), label)
      M._mark = nil
      if view then
        decor.set_dest(view.buf, nil)
      end
    end)
  end

  local s, d = source:sub(1, 8), dest:sub(1, 8)
  require("curate.ui.transient").open({
    title = ("rebase  %s → %s"):format(s, d),
    items = {
      { key = "e", arg = true, flag = "--skip-emptied", label = "skip emptied" },
      { key = "k", arg = true, flag = "--keep-divergent", label = "keep divergent" },
      {
        key = "d",
        label = ("onto  (-s %s -d %s, with descendants)"):format(s, d),
        run = function(flags)
          run({ "rebase", "-s", source, "-d", dest }, flags, "rebased " .. s .. " onto " .. d)
        end,
      },
      {
        key = "r",
        label = ("only this revision  (-r %s -d %s)"):format(s, d),
        run = function(flags)
          run({ "rebase", "-r", source, "-d", dest }, flags, "rebased " .. s .. " (rev only)")
        end,
      },
      {
        key = "b",
        label = ("whole branch  (-b %s -d %s)"):format(s, d),
        run = function(flags)
          run({ "rebase", "-b", source, "-d", dest }, flags, "rebased branch of " .. s)
        end,
      },
      {
        key = "A",
        label = ("insert after  (--insert-after %s)"):format(d),
        run = function(flags)
          run(
            { "rebase", "-s", source, "--insert-after", dest },
            flags,
            "inserted " .. s .. " after " .. d
          )
        end,
      },
      {
        key = "B",
        label = ("insert before  (--insert-before %s)"):format(d),
        run = function(flags)
          run(
            { "rebase", "-s", source, "--insert-before", dest },
            flags,
            "inserted " .. s .. " before " .. d
          )
        end,
      },
    },
  })
end

--- R — resolve conflicts in the change under the cursor, 3-way, via the curate
--- merge-editor. Delegates to ROUTE, which owns the merge-editor RPC handshake.
function M.resolve()
  require("curate.actions.route").resolve()
end

return M
