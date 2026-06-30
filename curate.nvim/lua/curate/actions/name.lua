-- actions/name.lua — NAME: describe · commit · new.

local jj = require("curate.jj")
local util = require("curate.actions.util")
local describe_view = require("curate.views.describe")

local M = {}

--- d — describe the change under the cursor (or @).
function M.describe()
  local id = util.cursor_change_id() or "@"
  describe_view.open(id)
end

--- c — commit: describe @ then `jj new` (seal this change, start the next).
function M.commit()
  describe_view.open("@", { after_new = true })
end

--- <CR> in the log — point @ at the change under the cursor (jj edit).
function M.edit_here()
  local id = util.cursor_change_id()
  if not id then
    return
  end
  util.mutate(jj, { "edit", id }, "editing " .. id:sub(1, 8))
end

--- Point @ at a specific change-id (jj edit). Used by surfaces that resolve the
--- target themselves (e.g. the revset workbench) rather than from the cursor.
---@param id string
function M.edit_target(id)
  if not id or id == "" then
    return
  end
  util.mutate(jj, { "edit", id }, "editing " .. id:sub(1, 8))
end

--- n — new change atop @ (or atop the change under the cursor).
function M.new()
  local id = util.cursor_change_id()
  local args = { "new" }
  if id and id ~= "" then
    vim.list_extend(args, { id })
  end
  util.mutate(jj, args, "new change")
end

return M
