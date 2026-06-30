-- actions/trust.lua — TRUST: undo · op restore · op-log.
--
-- What makes ROUTE fearless. Whole-repo, reversible, append-only: `op restore`
-- writes a NEW op, so forward history is never lost.

local jj = require("curate.jj")
local util = require("curate.actions.util")

local M = {}

--- u — undo the last operation (global, works from any curate buffer).
function M.undo()
  util.mutate(jj, { "undo" }, "undo")
end

--- g+ — redo (walk forward); jj models this as `op restore` to the next op,
--- but `jj undo` of the undo is the simplest correct inverse for v1.
function M.redo()
  util.mutate(jj, { "redo" }, "redo")
end

--- o — open the op-log time machine.
function M.oplog()
  require("curate.views.oplog").open()
end

--- Restore the repo to a given operation (append-only; confirmed by caller).
---@param op_id string
function M.op_restore(op_id)
  util.mutate(jj, { "op", "restore", op_id }, "restored to op " .. op_id:sub(1, 8))
end

--- L — evolog of the change under the cursor.
function M.evolog()
  local id = util.cursor_change_id() or "@"
  require("curate.views.evolog").open(id)
end

return M
