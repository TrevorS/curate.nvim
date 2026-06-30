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

--- r — rebase the marked source (or @) onto the change under the cursor.
function M.rebase()
  local t, view = util.cursor_target()
  local dest = t and t.id
  if not dest then
    return
  end
  local source = M._mark or "@"
  util.guard_immutable(t, "rebase onto", function()
    util.mutate(jj, { "rebase", "-s", source, "-d", dest }, "rebased " .. source:sub(1, 8))
    M._mark = nil
    if view then
      decor.set_dest(view.buf, nil)
    end
  end)
end

--- R — resolve conflicts in the change under the cursor via the merge editor.
function M.resolve()
  -- v1: drive jj's resolve; the interactive 3-way editor is a P4 refinement.
  util.mutate(jj, { "resolve" }, "resolve")
end

return M
