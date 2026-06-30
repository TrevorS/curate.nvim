-- ui/tree.lua — the foldable files -> hunks node model.
--
-- Given parsed diff files, produce a flat list of display nodes honouring each
-- file's fold state, and map a buffer row back to the node under the cursor so
-- actions ("squash this hunk", "restore this file") know their target.

local M = {}

---@class curate.TreeNode
---@field kind "file"|"hunk"
---@field file curate.DiffFile
---@field hunk curate.Hunk|nil
---@field hunk_index integer|nil
---@field folded boolean|nil      (file nodes only)

---@class curate.Tree
---@field files curate.DiffFile[]
---@field folded table<string,boolean>   path -> folded?
local Tree = {}
Tree.__index = Tree

---@param files curate.DiffFile[]
---@param prev curate.Tree|nil   carry fold state across refreshes
---@return curate.Tree
function M.new(files, prev)
  local folded = {}
  if prev then
    folded = prev.folded
  end
  return setmetatable({ files = files or {}, folded = folded }, Tree)
end

--- Toggle a file's fold by path.
---@param path string
function Tree:toggle(path)
  self.folded[path] = not self.folded[path]
end

---@param path string
---@return boolean
function Tree:is_folded(path)
  return self.folded[path] == true
end

--- Flatten into display nodes (file row, then its hunk rows unless folded).
---@return curate.TreeNode[]
function Tree:nodes()
  local nodes = {}
  for _, file in ipairs(self.files) do
    nodes[#nodes + 1] = { kind = "file", file = file, folded = self:is_folded(file.path) }
    if not self:is_folded(file.path) then
      for i, hunk in ipairs(file.hunks) do
        nodes[#nodes + 1] = { kind = "hunk", file = file, hunk = hunk, hunk_index = i }
      end
    end
  end
  return nodes
end

return M
