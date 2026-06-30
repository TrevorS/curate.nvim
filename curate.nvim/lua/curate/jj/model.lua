-- jj/model.lua — the typed data the whole plugin renders.
--
-- LuaCATS ---@class declarations give every module editor completion on the
-- model. Data never knows about windows. (§D of the Lua Architecture sketch.)

---@class curate.Change
---@field id       string    change_id — the anchor for every mark/buffer/op
---@field commit   string    commit_id.short(8)
---@field email    string    author email
---@field ago      string    committer timestamp, humanised
---@field subject   string   description.first_line()
---@field parents  string[]  parent change-ids (DAG edges; we lay out the graph)
---@field flags    curate.ChangeFlags

---@class curate.ChangeFlags
---@field conflict  boolean
---@field divergent boolean
---@field immutable boolean
---@field current   boolean  is this @ (the working copy)?
---@field empty     boolean  no diff vs parent

---@class curate.Op
---@field id       string    operation id (short)
---@field ago      string    when it ran
---@field summary  string    one-line description ("absorb 3 hunks")
---@field current  boolean   is this the op @ currently points at?

---@class curate.FileChange
---@field path    string
---@field status  string     "M" | "A" | "D" | "R" | "C"
---@field added   integer
---@field removed integer

---@class curate.Hunk
---@field file    string
---@field header  string     "@@ -a,b +c,d @@ ctx"
---@field old_start integer
---@field old_count integer
---@field new_start integer
---@field new_count integer
---@field lines   string[]   raw unified-diff body lines (with +/-/space prefix)

local M = {}

--- Short, stable display id for a change (first 8 of change_id).
---@param c curate.Change
---@return string
function M.short(c)
  return (c.id or ""):sub(1, 8)
end

--- A single-character status glyph reflecting a change's flags.
---@param c curate.Change
---@return string
function M.glyph(c)
  if c.flags.current then
    return "@"
  elseif c.flags.immutable then
    return "◆"
  else
    return "○"
  end
end

return M
