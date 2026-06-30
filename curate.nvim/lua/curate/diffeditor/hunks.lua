-- diffeditor/hunks.lua — the hunk engine behind the diff-editor.
--
-- Pure functions over line arrays (no vim/jj), so the load-bearing logic of the
-- wedge — compute hunks between $left and $right, then reconstruct $right from
-- only the *selected* hunks — is fully unit-testable.

local M = {}

---@class curate.EditHunk
---@field old_start integer   1-based index of first old line in the hunk
---@field old_count integer   number of old lines replaced (0 = pure insertion)
---@field old_lines string[]  the replaced old lines
---@field new_lines string[]  the replacement new lines
---@field index integer       position in the file's hunk list (for selection)

-- Longest common subsequence of two line arrays -> list of matched index pairs.
---@param a string[]
---@param b string[]
---@return integer[][]  pairs {ai, bi} (1-based) of equal lines, in order
local function lcs_pairs(a, b)
  local n, m = #a, #b
  -- DP table of LCS lengths.
  local dp = {}
  for i = 0, n do
    dp[i] = {}
    dp[i][m] = 0
  end
  for j = 0, m do
    dp[n][j] = 0
  end
  for i = n - 1, 0, -1 do
    for j = m - 1, 0, -1 do
      if a[i + 1] == b[j + 1] then
        dp[i][j] = dp[i + 1][j + 1] + 1
      else
        dp[i][j] = math.max(dp[i + 1][j], dp[i][j + 1])
      end
    end
  end
  local pairs_out = {}
  local i, j = 0, 0
  while i < n and j < m do
    if a[i + 1] == b[j + 1] then
      pairs_out[#pairs_out + 1] = { i + 1, j + 1 }
      i, j = i + 1, j + 1
    elseif dp[i + 1][j] >= dp[i][j + 1] then
      i = i + 1
    else
      j = j + 1
    end
  end
  return pairs_out
end

--- Compute the hunks turning `old` into `new`.
---@param old string[]
---@param new string[]
---@return curate.EditHunk[]
function M.compute(old, new)
  local matches = lcs_pairs(old, new)
  -- Sentinel match past the end simplifies the trailing segment.
  matches[#matches + 1] = { #old + 1, #new + 1 }

  local hunks = {}
  local oi, ni = 1, 1 -- next unconsumed old / new line (1-based)
  for _, pair in ipairs(matches) do
    local ma, mb = pair[1], pair[2]
    if ma > oi or mb > ni then
      -- Lines [oi, ma) in old and [ni, mb) in new form a change region.
      local old_lines, new_lines = {}, {}
      for k = oi, ma - 1 do
        old_lines[#old_lines + 1] = old[k]
      end
      for k = ni, mb - 1 do
        new_lines[#new_lines + 1] = new[k]
      end
      hunks[#hunks + 1] = {
        old_start = oi,
        old_count = ma - oi,
        old_lines = old_lines,
        new_lines = new_lines,
        index = #hunks + 1,
      }
    end
    oi, ni = ma + 1, mb + 1
  end
  return hunks
end

--- Reconstruct a file from `old` applying only the selected hunks.
--- Deselected hunks keep the old content; selected hunks take the new content.
---@param old string[]
---@param hunks curate.EditHunk[]
---@param selected table<integer,boolean>   hunk.index -> selected?
---@return string[]
function M.apply(old, hunks, selected)
  local result = {}
  local oi = 1
  for _, h in ipairs(hunks) do
    -- copy unchanged old lines before this hunk
    for k = oi, h.old_start - 1 do
      result[#result + 1] = old[k]
    end
    if selected[h.index] then
      for _, l in ipairs(h.new_lines) do
        result[#result + 1] = l
      end
    else
      for _, l in ipairs(h.old_lines) do
        result[#result + 1] = l
      end
    end
    oi = h.old_start + h.old_count
  end
  -- trailing unchanged old lines
  for k = oi, #old do
    result[#result + 1] = old[k]
  end
  return result
end

return M
