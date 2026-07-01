-- diffeditor/worddiff.lua — intra-line ("word-level") diff for a hunk.
--
-- A hunk is a block of removed lines followed by a block of added lines. To
-- emphasise only the parts that actually changed, we tokenise both blocks
-- (word runs, punctuation, and newline anchors), align them with the same LCS
-- the hunk engine uses, and report the byte ranges of the *unmatched* word
-- tokens — but only for lines that still share a word with the other side
-- (a wholly-rewritten line just keeps its add/remove tint). Pure functions over
-- line arrays, so it unit-tests without vim/jj. (Sibling of hunks.lua.)

local hunks = require("curate.diffeditor.hunks")

local M = {}

-- Above this token-product a full LCS table is not worth building; giant hunks
-- (whole-file rewrites) skip intra-line emphasis and keep just the line tint.
local MAX_PRODUCT = 200000

--- Tokenise lines into { text, line, scol, ecol, kind } tokens, where kind is
--- "word" ([%w_]+ runs), "space" (whitespace), or "punct" (any other char).
--- All kinds anchor the LCS; only "word" tokens decide whether two lines are
--- *related* (a shared word), and "space" is never emphasised. Newlines are
--- emitted as anchors (line 0) so the LCS respects line breaks.
---@param lines string[]
---@return table[]
local function tokenize(lines)
  local toks = {}
  for li, line in ipairs(lines) do
    local i, n = 1, #line
    while i <= n do
      local s, e = line:find("^[%w_]+", i)
      if s then
        toks[#toks + 1] =
          { text = line:sub(s, e), line = li, scol = s - 1, ecol = e, kind = "word" }
        i = e + 1
      else
        local ch = line:sub(i, i)
        local kind = ch:match("%s") and "space" or "punct"
        toks[#toks + 1] = { text = ch, line = li, scol = i - 1, ecol = i, kind = kind }
        i = i + 1
      end
    end
    if li < #lines then
      toks[#toks + 1] = { text = "\n", line = 0 } -- anchor only
    end
  end
  return toks
end

--- Merge sorted, possibly touching ranges into contiguous ones.
---@param ranges integer[][]
---@return integer[][]
local function merge(ranges)
  table.sort(ranges, function(a, b)
    return a[1] < b[1]
  end)
  local out = {}
  for _, r in ipairs(ranges) do
    local last = out[#out]
    if last and r[1] <= last[2] then
      if r[2] > last[2] then
        last[2] = r[2]
      end
    else
      out[#out + 1] = { r[1], r[2] }
    end
  end
  return out
end

--- Changed word ranges per line, for the removed and added blocks of a hunk.
---@param old_lines string[]
---@param new_lines string[]
---@return table<integer, integer[][]> del, table<integer, integer[][]> ins
---        line index -> merged {scol, ecol} byte ranges (only partial changes)
function M.ranges(old_lines, new_lines)
  if #old_lines == 0 or #new_lines == 0 then
    return {}, {}
  end
  local ot, nt = tokenize(old_lines), tokenize(new_lines)
  if #ot * #nt > MAX_PRODUCT then
    return {}, {}
  end
  local ov, nv = {}, {}
  for i, t in ipairs(ot) do
    ov[i] = t.text
  end
  for i, t in ipairs(nt) do
    nv[i] = t.text
  end
  local matched_o, matched_n = {}, {}
  for _, p in ipairs(hunks.lcs_pairs(ov, nv)) do
    matched_o[p[1]], matched_n[p[2]] = true, true
  end

  -- Per side: a line gets intra-line emphasis only if it shares a real word
  -- with the other side (proving it's the *same line, edited* rather than a
  -- wholly-different line). Emphasise every unmatched non-space token on it.
  local function side(toks, matched)
    local related, ranges = {}, {}
    for i, t in ipairs(toks) do
      if t.kind == "word" and matched[i] then
        related[t.line] = true
      elseif t.kind ~= "space" and not matched[i] then
        ranges[t.line] = ranges[t.line] or {}
        ranges[t.line][#ranges[t.line] + 1] = { t.scol, t.ecol }
      end
    end
    local out = {}
    for line, rs in pairs(ranges) do
      if related[line] then
        out[line] = merge(rs)
      end
    end
    return out
  end

  return side(ot, matched_o), side(nt, matched_n)
end

return M
