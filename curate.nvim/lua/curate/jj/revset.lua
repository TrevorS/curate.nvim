-- jj/revset.lua — typed revset builders.
--
-- Keeps revset strings in one place rather than scattered literals, and gives
-- callers small composable helpers instead of hand-concatenating expressions.

local M = {}

-- The home/log default: @ plus recent ancestors, trunk, and bookmark heads.
-- Mirrors the board's default revset, trimmed for a focused curate view.
M.DEFAULT_LOG = "@ | ancestors(@, 4) | trunk() | bookmarks()"

---@param id string change-id
---@return string
function M.change(id)
  -- Quote nothing: change-ids are [k-z] only, safe as bare revset atoms.
  return id
end

---@param id string
---@return string  the change and all its descendants
function M.descendants(id)
  return id .. "::"
end

---@param id string
---@return string  ancestors of a change
function M.ancestors(id)
  return "::" .. id
end

--- Bookmarks not yet pushed to origin — the default push set.
---@return string
function M.unpushed()
  return "remote_bookmarks(remote=origin)..@"
end

return M
