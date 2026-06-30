-- jj/diff.lua — parse `jj diff --git` (unified/git diff) into typed files+hunks.
--
-- Used by the status tree (files -> hunks fold model) and by the diff-editor's
-- write-back (revert de-selected hunk regions in $right). Pure string -> table;
-- no vim/jj calls, so it unit-tests in isolation.

local M = {}

---@class curate.DiffFile
---@field path     string
---@field old_path string|nil   set for renames
---@field status   string       "M"|"A"|"D"|"R"
---@field binary   boolean
---@field hunks    curate.Hunk[]
---@field added    integer
---@field removed  integer

-- "@@ -a,b +c,d @@ ctx"  (b and d optional, default 1)
local HUNK = "^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@(.*)$"

---@param spec string  e.g. "a/foo b/foo" tail of the `diff --git` line
---@return string path
local function strip_ab(spec)
  -- `b/<path>` is the post-image path; prefer it.
  return (spec:gsub("^[ab]/", ""))
end

--- Parse a full `jj diff --git` blob.
---@param text string
---@return curate.DiffFile[]
function M.parse(text)
  local files = {}
  local cur, hunk = nil, nil

  local function close_hunk()
    if cur and hunk then
      cur.hunks[#cur.hunks + 1] = hunk
      hunk = nil
    end
  end

  for line in vim.gsplit(text or "", "\n", { plain = true }) do
    if line:sub(1, 11) == "diff --git " then
      close_hunk()
      -- Recover both paths (handles spaces by matching " b/" as the splitter).
      local rest = line:sub(12)
      local a, b = rest:match("^a/(.-) b/(.+)$")
      local path = b and strip_ab("b/" .. b) or strip_ab(rest)
      cur = {
        path = path,
        old_path = (a and a ~= b) and a or nil,
        status = "M",
        binary = false,
        hunks = {},
        added = 0,
        removed = 0,
      }
      files[#files + 1] = cur
    elseif cur and line:match("^new file") then
      cur.status = "A"
    elseif cur and line:match("^deleted file") then
      cur.status = "D"
    elseif cur and line:match("^rename ") then
      cur.status = "R"
    elseif cur and line:match("^Binary files") then
      cur.binary = true
    elseif cur and line:match("^@@ ") then
      close_hunk()
      local os_, oc, ns_, nc, ctx = line:match(HUNK)
      if os_ then
        hunk = {
          file = cur.path,
          header = line,
          old_start = tonumber(os_),
          old_count = tonumber(oc ~= "" and oc or "1"),
          new_start = tonumber(ns_),
          new_count = tonumber(nc ~= "" and nc or "1"),
          context = ctx or "",
          lines = {},
        }
      end
    elseif hunk and (line:sub(1, 1) == "+" or line:sub(1, 1) == "-" or line:sub(1, 1) == " ") then
      hunk.lines[#hunk.lines + 1] = line
      local c = line:sub(1, 1)
      if c == "+" then
        cur.added = cur.added + 1
      elseif c == "-" then
        cur.removed = cur.removed + 1
      end
    end
    -- index/--- /+++ lines are ignored: topology comes from the @@ headers.
  end
  close_hunk()
  return files
end

--- Total hunk count across files.
---@param files curate.DiffFile[]
---@return integer
function M.hunk_count(files)
  local n = 0
  for _, f in ipairs(files) do
    n = n + #f.hunks
  end
  return n
end

return M
