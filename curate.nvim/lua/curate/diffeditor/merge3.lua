-- diffeditor/merge3.lua — the 3-way merge engine behind the merge-editor.
--
-- Pure functions over line arrays (no vim/jj), so conflict chunking and
-- assembly are fully unit-testable. jj's ui.merge-editor hands us three trees:
-- $base (common ancestor), $left and $right (the two sides), and an empty
-- $output we must fill with the resolved content. We chunk the file into
-- segments using base lines common to *all three* as anchors (classic diff3),
-- classify each gap, and let the view pick a side per conflict.

local hunks = require("curate.diffeditor.hunks")

local M = {}

---@class curate.MergeSegment
---@field kind "stable"|"auto"|"conflict"
---@field lines string[]|nil    resolved lines (stable/auto); nil for conflict
---@field side "left"|"right"|"both"|nil   which side an auto chunk took
---@field base string[]|nil     conflict slices (also kept on auto for display)
---@field left string[]|nil
---@field right string[]|nil
---@field choice "left"|"right"|"base"|"left+right"|"right+left"|nil  user pick

---@param t string[]
---@param i integer  1-based inclusive
---@param j integer  1-based inclusive
---@return string[]
local function slice(t, i, j)
  local out = {}
  for k = i, j do
    out[#out + 1] = t[k]
  end
  return out
end

---@param a string[]
---@param b string[]
---@return boolean
local function eq(a, b)
  if #a ~= #b then
    return false
  end
  for i = 1, #a do
    if a[i] ~= b[i] then
      return false
    end
  end
  return true
end

--- Chunk a 3-way merge into ordered segments.
---@param base string[]
---@param left string[]
---@param right string[]
---@return curate.MergeSegment[]
function M.chunk(base, left, right)
  local bl = hunks.lcs_pairs(base, left) -- {bi, li} pairs
  local br = hunks.lcs_pairs(base, right) -- {bi, ri} pairs
  local Lmap, Rmap = {}, {}
  for _, p in ipairs(bl) do
    Lmap[p[1]] = p[2]
  end
  for _, p in ipairs(br) do
    Rmap[p[1]] = p[2]
  end

  -- Anchors: base indices matched in BOTH sides, in increasing order, bracketed
  -- by sentinels so the leading/trailing gaps fall out of the same loop.
  local anchors = { 0 }
  for bi = 1, #base do
    if Lmap[bi] and Rmap[bi] then
      anchors[#anchors + 1] = bi
    end
  end
  anchors[#anchors + 1] = #base + 1
  Lmap[0], Rmap[0] = 0, 0
  Lmap[#base + 1], Rmap[#base + 1] = #left + 1, #right + 1

  local segs = {}
  for k = 1, #anchors - 1 do
    local b1, b2 = anchors[k], anchors[k + 1]
    -- The gap strictly between the two anchors, on each side.
    local bs = slice(base, b1 + 1, b2 - 1)
    local ls = slice(left, Lmap[b1] + 1, Lmap[b2] - 1)
    local rs = slice(right, Rmap[b1] + 1, Rmap[b2] - 1)
    if #bs > 0 or #ls > 0 or #rs > 0 then
      if eq(ls, bs) then
        segs[#segs + 1] =
          { kind = "auto", side = "right", lines = rs, base = bs, left = ls, right = rs }
      elseif eq(rs, bs) then
        segs[#segs + 1] =
          { kind = "auto", side = "left", lines = ls, base = bs, left = ls, right = rs }
      elseif eq(ls, rs) then
        segs[#segs + 1] =
          { kind = "auto", side = "both", lines = ls, base = bs, left = ls, right = rs }
      else
        segs[#segs + 1] = { kind = "conflict", base = bs, left = ls, right = rs, choice = nil }
      end
    end
    -- Emit the real anchor line that closes this gap (skip the end sentinel).
    if b2 <= #base then
      segs[#segs + 1] = { kind = "stable", lines = { base[b2] } }
    end
  end
  return segs
end

--- How many conflict segments still need a choice.
---@param segs curate.MergeSegment[]
---@return integer unresolved, integer total
function M.unresolved(segs)
  local unres, total = 0, 0
  for _, s in ipairs(segs) do
    if s.kind == "conflict" then
      total = total + 1
      if not s.choice then
        unres = unres + 1
      end
    end
  end
  return unres, total
end

--- The resolved lines for one conflict segment, given its choice.
---@param s curate.MergeSegment
---@return string[]
local function conflict_lines(s)
  local c = s.choice
  if c == "left" then
    return s.left
  elseif c == "right" then
    return s.right
  elseif c == "base" then
    return s.base
  elseif c == "left+right" then
    local out = {}
    vim.list_extend(out, s.left)
    vim.list_extend(out, s.right)
    return out
  elseif c == "right+left" then
    local out = {}
    vim.list_extend(out, s.right)
    vim.list_extend(out, s.left)
    return out
  end
  return s.base -- unresolved fallback (assemble guards against this)
end

--- Assemble the final resolved file from the segments and their choices.
--- Returns nil if any conflict is still unresolved.
---@param segs curate.MergeSegment[]
---@return string[]|nil
function M.assemble(segs)
  if (M.unresolved(segs)) > 0 then
    return nil
  end
  local out = {}
  for _, s in ipairs(segs) do
    if s.kind == "conflict" then
      vim.list_extend(out, conflict_lines(s))
    else
      vim.list_extend(out, s.lines)
    end
  end
  return out
end

-- Exposed for tests.
M._conflict_lines = conflict_lines

return M
